# Troubleshooting Guide

This guide helps you resolve common issues when using thecodingmachine PHP Docker images.

## Table of Contents

- [Extension Issues](#extension-issues)
- [Permission Issues](#permission-issues)
- [Apache Configuration Issues](#apache-configuration-issues)
- [PHP Configuration Issues](#php-configuration-issues)
- [Build Issues](#build-issues)
- [Performance Issues](#performance-issues)
- [Xdebug Issues](#xdebug-issues)
- [Composer Issues](#composer-issues)
- [NodeJS Issues](#nodejs-issues)

---

## Extension Issues

### Extension Not Loading

**Problem:** You enabled an extension with `PHP_EXTENSION_XXX=1` but `php -m` doesn't show it.

**Solutions:**

1. **Check if extension is available in your image:**
   ```bash
   docker run --rm thecodingmachine/php:8.2-v4-apache bash -c "ls /usr/local/etc/php/conf.d/"
   ```

2. **Check extension availability for your PHP version:**
   - Some extensions are not available in all PHP versions (see README.md)
   - For example: `mcrypt` is not available in PHP 7.3+
   - `ffi` is only available in PHP 7.4+

3. **Check the extension name:**
   ```bash
   # Correct
   PHP_EXTENSION_PGSQL=1

   # Incorrect (wrong name)
   PHP_EXTENSION_POSTGRESQL=1
   ```

4. **Verify environment variable is set:**
   ```bash
   docker run --rm -e PHP_EXTENSION_REDIS=1 thecodingmachine/php:8.2-v4-cli php -r "echo getenv('PHP_EXTENSION_REDIS');"
   ```

### Extension Installation Fails in Slim Image

**Problem:** Building a slim image with extensions fails.

**Solutions:**

1. **Ensure ARG is before FROM:**
   ```dockerfile
   # Correct
   ARG PHP_EXTENSIONS="mysqli redis"
   FROM thecodingmachine/php:8.2-v4-slim-apache

   # Incorrect - won't work
   FROM thecodingmachine/php:8.2-v4-slim-apache
   ARG PHP_EXTENSIONS="mysqli redis"
   ```

2. **Use spaces, not commas:**
   ```dockerfile
   # Correct
   ARG PHP_EXTENSIONS="mysqli redis pdo_mysql"

   # Incorrect
   ARG PHP_EXTENSIONS="mysqli,redis,pdo_mysql"
   ```

3. **Check build logs for specific errors:**
   ```bash
   docker build --progress=plain --no-cache -t myapp .
   ```

### Common Extension Names

| Extension | Correct Name | Common Mistakes |
|-----------|--------------|-----------------|
| PostgreSQL | `pgsql` or `pdo_pgsql` | `postgresql`, `postgres` |
| MySQL | `mysqli` or `pdo_mysql` | `mysql` |
| SQLite | `sqlite3` or `pdo_sqlite` | `sqlite` |
| ImageMagick | `imagick` | `imagemagick` |
| YAML | `yaml` | `yml` |

---

## Permission Issues

### Files Created by Container Have Wrong Ownership

**Problem:** Files created by the container are owned by root or wrong user.

**Solutions:**

1. **Set user/group ID to match host:**
   ```yaml
   environment:
     DOCKER_USER_UID: 1000
     DOCKER_USER_GID: 1000
   ```

2. **On Linux/Mac, use your current user ID:**
   ```yaml
   environment:
     DOCKER_USER_UID: ${UID:-1000}
     DOCKER_USER_GID: ${GID:-1000}
   ```

3. **Use startup commands (advanced):**
   ```yaml
   environment:
     STARTUP_COMMAND_1: "sudo usermod -u 1000 docker"
     STARTUP_COMMAND_2: "sudo groupmod -g 1000 docker"
   ```

### Permission Denied When Writing to Volumes

**Problem:** Container cannot write to mounted volumes.

**Solutions:**

1. **Fix volume permissions on host:**
   ```bash
   chmod -R 777 ./storage
   # Or more restrictive
   chmod -R 755 ./storage
   chown -R 1000:1000 ./storage
   ```

2. **Check SELinux (Fedora/RHEL/CentOS):**
   ```bash
   # Add :z or :Z to volume mount
   volumes:
     - ./src:/var/www/html:z
   ```

3. **On Windows, ensure file sharing is enabled:**
   - Docker Desktop → Settings → Resources → File Sharing
   - Add your project directory

---

## Apache Configuration Issues

### 404 Not Found or Wrong Document Root

**Problem:** Apache serves wrong directory or shows 404.

**Solutions:**

1. **Set correct document root:**
   ```yaml
   environment:
     APACHE_DOCUMENT_ROOT: /var/www/html/public
   ```

2. **For Laravel/Symfony:**
   ```dockerfile
   ENV APACHE_DOCUMENT_ROOT=/var/www/html/public
   ```

3. **Verify document root:**
   ```bash
   docker exec -it <container> bash
   cat /etc/apache2/sites-enabled/000-default.conf | grep DocumentRoot
   ```

### .htaccess Not Working

**Problem:** Apache ignores .htaccess files.

**Solutions:**

1. **Enable AllowOverride:**
   ```yaml
   environment:
     APACHE_ALLOW_OVERRIDE: "All"
   ```

2. **Ensure mod_rewrite is enabled:**
   ```bash
   docker exec -it <container> apache2ctl -M | grep rewrite
   ```

### Custom Apache Configuration

**Problem:** Need custom Apache configuration.

**Solution:**

```dockerfile
FROM thecodingmachine/php:8.2-v4-apache

# Copy custom Apache config
COPY my-vhost.conf /etc/apache2/sites-available/000-default.conf

# Or add extra config
COPY my-apache.conf /etc/apache2/conf-available/
RUN a2enconf my-apache
```

---

## PHP Configuration Issues

### Environment Variables Not Working

**Problem:** `PHP_INI_*` variables don't change PHP settings.

**Solutions:**

1. **Use correct variable format:**
   ```yaml
   # Correct
   PHP_INI_MEMORY_LIMIT: 512M
   PHP_INI_MAX_EXECUTION_TIME: 300

   # Incorrect (missing PHP_INI_ prefix)
   MEMORY_LIMIT: 512M
   ```

2. **For nested ini settings, use double underscore:**
   ```yaml
   # For [xdebug] section
   PHP_INI_XDEBUG__MODE: debug
   PHP_INI_XDEBUG__CLIENT_HOST: host.docker.internal

   # For [opcache] section
   PHP_INI_OPCACHE__ENABLE: 1
   PHP_INI_OPCACHE__MEMORY_CONSUMPTION: 256
   ```

3. **Verify settings:**
   ```bash
   docker exec <container> php -i | grep memory_limit
   ```

### Upload Size Limits

**Problem:** File uploads fail for large files.

**Solution:**

```yaml
environment:
  PHP_INI_UPLOAD_MAX_FILESIZE: 100M
  PHP_INI_POST_MAX_SIZE: 100M
  PHP_INI_MEMORY_LIMIT: 256M
  # If using Apache
  APACHE_MAX_REQUEST_SIZE: 100M
```

### Timeout Issues

**Problem:** Scripts timeout during execution.

**Solution:**

```yaml
environment:
  PHP_INI_MAX_EXECUTION_TIME: 300
  PHP_INI_MAX_INPUT_TIME: 300
  # For CLI scripts
  PHP_INI_CLI__MAX_EXECUTION_TIME: 0
```

---

## Build Issues

### Docker Build Fails with "No Space Left on Device"

**Solutions:**

1. **Clean Docker cache:**
   ```bash
   docker system prune -a
   docker builder prune -a
   ```

2. **Increase Docker disk space:**
   - Docker Desktop → Settings → Resources → Disk image size

### Build Extremely Slow

**Solutions:**

1. **Use .dockerignore:**
   ```
   # .dockerignore
   node_modules/
   vendor/
   .git/
   storage/logs/*
   storage/framework/cache/*
   ```

2. **Use multi-stage builds:**
   ```dockerfile
   FROM thecodingmachine/php:8.2-v4-slim-apache AS builder
   # Build steps...

   FROM thecodingmachine/php:8.2-v4-slim-apache
   COPY --from=builder /var/www/html /var/www/html
   ```

3. **Enable BuildKit:**
   ```bash
   DOCKER_BUILDKIT=1 docker build -t myapp .
   ```

### Composer Install Fails

**Problem:** Composer fails during build.

**Solutions:**

1. **Increase memory limit:**
   ```dockerfile
   ENV PHP_INI_MEMORY_LIMIT=-1
   RUN composer install
   ```

2. **Use authentication for private repos:**
   ```dockerfile
   RUN composer config -g github-oauth.github.com <token>
   RUN composer install
   ```

3. **Use --no-scripts if scripts fail:**
   ```dockerfile
   RUN composer install --no-scripts --no-dev
   RUN composer run-script post-install-cmd
   ```

---

## Performance Issues

### Container Starts Very Slowly

**Problem:** Container takes minutes to start.

**Solutions:**

1. **Use fat images for development:**
   ```yaml
   # Slow (compiles extensions on each start)
   image: thecodingmachine/php:8.2-v4-slim-apache
   environment:
     PHP_EXTENSIONS: mysqli redis gd intl

   # Fast (extensions pre-installed)
   image: thecodingmachine/php:8.2-v4-apache
   environment:
     PHP_EXTENSION_MYSQLI: 1
     PHP_EXTENSION_REDIS: 1
   ```

2. **Disable unnecessary startup commands:**
   ```yaml
   environment:
     STARTUP_COMMAND_1: ""
   ```

3. **Check startup logs:**
   ```bash
   docker logs <container> 2>&1 | less
   ```

### PHP Execution Slow

**Solutions:**

1. **Enable OPcache (production):**
   ```yaml
   environment:
     PHP_INI_OPCACHE__ENABLE: 1
     PHP_INI_OPCACHE__MEMORY_CONSUMPTION: 256
     PHP_INI_OPCACHE__MAX_ACCELERATED_FILES: 20000
     PHP_INI_OPCACHE__VALIDATE_TIMESTAMPS: 0
   ```

2. **On macOS, avoid mounted volumes for vendor/:**
   ```yaml
   volumes:
     - ./:/var/www/html
     # Exclude vendor for better performance
     - /var/www/html/vendor
   ```

3. **Use delegated/cached mount modes (macOS):**
   ```yaml
   volumes:
     - ./:/var/www/html:delegated
   ```

---

## Xdebug Issues

### Xdebug Not Connecting to IDE

**Solutions:**

1. **Enable Xdebug correctly:**
   ```yaml
   environment:
     PHP_EXTENSION_XDEBUG: 1
     PHP_INI_XDEBUG__MODE: debug
     PHP_INI_XDEBUG__START_WITH_REQUEST: yes
     PHP_INI_XDEBUG__CLIENT_HOST: host.docker.internal
     PHP_INI_XDEBUG__CLIENT_PORT: 9003
   ```

2. **For Linux, use host IP:**
   ```yaml
   environment:
     PHP_EXTENSION_XDEBUG: 1
     PHP_INI_XDEBUG__MODE: debug
     PHP_INI_XDEBUG__CLIENT_HOST: 172.17.0.1
   ```

3. **Configure IDE:**
   - PHPStorm: Enable "Start Listening for PHP Debug Connections"
   - VS Code: Install PHP Debug extension, configure launch.json

4. **Verify Xdebug is loaded:**
   ```bash
   docker exec <container> php -v
   # Should show "with Xdebug v3.x.x"
   ```

### Xdebug Makes Application Too Slow

**Solution:**

```yaml
# Only enable when needed
environment:
  PHP_EXTENSION_XDEBUG: ${XDEBUG_ENABLE:-0}
```

Then:
```bash
XDEBUG_ENABLE=1 docker-compose up
```

---

## Composer Issues

### Composer Not Found (Slim Image)

**Problem:** `composer` command not available in slim images.

**Solutions:**

1. **Install Composer in Dockerfile:**
   ```dockerfile
   FROM thecodingmachine/php:8.2-v4-slim-apache

   COPY --from=composer:2 /usr/bin/composer /usr/bin/composer
   ```

2. **Or use fat image** (has Composer pre-installed)

### Composer Out of Memory

**Solution:**

```dockerfile
RUN COMPOSER_MEMORY_LIMIT=-1 composer install
```

Or:

```yaml
environment:
  PHP_INI_MEMORY_LIMIT: -1
```

---

## NodeJS Issues

### NodeJS Not Found

**Problem:** `npm` or `node` command not available.

**Solution:**

Use Node variant:
```dockerfile
# Instead of
FROM thecodingmachine/php:8.2-v4-apache

# Use
FROM thecodingmachine/php:8.2-v4-apache-node18
```

### Wrong Node Version

**Problem:** Need specific Node version.

**Solution:**

Available Node variants: 10, 12, 14, 16, 18

```dockerfile
FROM thecodingmachine/php:8.2-v4-apache-node18  # Node 18.x
FROM thecodingmachine/php:8.2-v4-apache-node16  # Node 16.x
```

### Yarn Not Installed

**Solution:**

```dockerfile
FROM thecodingmachine/php:8.2-v4-apache-node18

RUN npm install -g yarn
```

---

## Getting More Help

If your issue is not listed here:

1. **Check container logs:**
   ```bash
   docker logs <container-name>
   docker logs -f <container-name>  # Follow logs
   ```

2. **Inspect running container:**
   ```bash
   docker exec -it <container-name> bash
   php -v
   php -m
   php -i
   apache2ctl -M
   ```

3. **Verify environment variables:**
   ```bash
   docker exec <container-name> env | grep PHP
   ```

4. **Check GitHub issues:**
   - https://github.com/thecodingmachine/docker-images-php/issues

5. **Create a minimal reproduction:**
   - Isolate the problem
   - Create a simple Dockerfile or docker-compose.yml
   - Report issue on GitHub with details

---

## Debug Checklist

When reporting issues, include:

- [ ] Image name and tag (e.g., `thecodingmachine/php:8.2-v4-apache`)
- [ ] Full error message
- [ ] Relevant Dockerfile or docker-compose.yml
- [ ] Environment variables being set
- [ ] Output of `docker logs <container>`
- [ ] Host OS (Windows/Mac/Linux)
- [ ] Docker version (`docker --version`)
- [ ] What you've already tried

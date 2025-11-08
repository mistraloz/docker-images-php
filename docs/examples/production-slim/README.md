# Production Slim Image Example

This example demonstrates how to build an optimized production Docker image using the slim variant.

## Key Features

- ✅ **Minimal image size** - Only required extensions installed
- ✅ **Optimized for production** - OPcache enabled, debug disabled
- ✅ **Security hardened** - No dev dependencies, PHP version hidden
- ✅ **Health checks** - Built-in container health monitoring
- ✅ **Layer caching** - Optimized build order for faster rebuilds

## Image Size Comparison

| Image Type | Approximate Size |
|------------|-----------------|
| Fat image | ~800MB |
| Slim image (this example) | ~350MB |
| Reduction | **56% smaller** |

## Building the Image

```bash
docker build -t myapp:production .
```

### Build Arguments

The extensions are specified as an ARG before FROM:

```dockerfile
ARG PHP_EXTENSIONS="mysqli pdo_mysql redis opcache gd intl"
```

To customize extensions during build:

```bash
docker build \
  --build-arg PHP_EXTENSIONS="mysqli pdo_mysql redis" \
  -t myapp:production .
```

## Running the Image

### Basic Run

```bash
docker run -d \
  -p 80:80 \
  --name myapp \
  -e APP_ENV=production \
  myapp:production
```

### With Docker Compose

```yaml
version: '3.8'

services:
  app:
    build: .
    ports:
      - "80:80"
    environment:
      APP_ENV: production
      DB_HOST: db
      DB_DATABASE: myapp
      DB_USERNAME: myapp
      DB_PASSWORD: secret
    restart: unless-stopped

  db:
    image: mysql:8.0
    environment:
      MYSQL_DATABASE: myapp
      MYSQL_USER: myapp
      MYSQL_PASSWORD: secret
      MYSQL_ROOT_PASSWORD: rootsecret
    volumes:
      - db_data:/var/lib/mysql
    restart: unless-stopped

volumes:
  db_data:
```

## Production Configuration

### PHP Settings (Optimized)

The Dockerfile configures PHP for production:

```dockerfile
ENV PHP_INI_MEMORY_LIMIT=256M
ENV PHP_INI_OPCACHE__ENABLE=1
ENV PHP_INI_OPCACHE__MEMORY_CONSUMPTION=256
ENV PHP_INI_OPCACHE__INTERNED_STRINGS_BUFFER=16
ENV PHP_INI_OPCACHE__MAX_ACCELERATED_FILES=20000
ENV PHP_INI_OPCACHE__VALIDATE_TIMESTAMPS=0  # Important for production!
ENV PHP_INI_DISPLAY_ERRORS=0                # Never show errors
ENV PHP_INI_LOG_ERRORS=1                    # Log to file instead
ENV PHP_INI_EXPOSE_PHP=0                    # Hide PHP version
```

### OPcache Explained

**What is OPcache?**
- Stores precompiled PHP bytecode in memory
- Dramatically improves performance (2-3x faster)
- Reduces disk I/O

**Important Settings:**

- `opcache.enable=1` - Enable OPcache
- `opcache.memory_consumption=256` - Memory for cached code
- `opcache.validate_timestamps=0` - **Critical**: Don't check for file changes
  - In production, code doesn't change, so skip file checks
  - Requires container restart when code changes
  - Major performance boost

### Security Hardening

1. **No dev dependencies**:
   ```bash
   composer install --no-dev
   ```

2. **Hide PHP version**:
   ```dockerfile
   ENV PHP_INI_EXPOSE_PHP=0
   ```

3. **Disable error display**:
   ```dockerfile
   ENV PHP_INI_DISPLAY_ERRORS=0
   ENV PHP_INI_LOG_ERRORS=1
   ```

4. **Minimal attack surface**:
   - Only essential extensions installed
   - No unnecessary packages

## Multi-Stage Build Alternative

For even smaller images, use multi-stage builds:

```dockerfile
# Stage 1: Build dependencies
FROM thecodingmachine/php:8.2-v4-cli AS builder

COPY --from=composer:2 /usr/bin/composer /usr/bin/composer

WORKDIR /app
COPY composer.json composer.lock ./
RUN composer install --no-dev --optimize-autoloader

COPY . .

# Stage 2: Production image
ARG PHP_EXTENSIONS="mysqli pdo_mysql redis opcache"
FROM thecodingmachine/php:8.2-v4-slim-apache

COPY --from=builder /app /var/www/html

# ... rest of configuration
```

## Deployment Strategies

### Docker Swarm

```bash
docker stack deploy -c docker-compose.yml myapp
```

### Kubernetes

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: myapp
spec:
  replicas: 3
  template:
    spec:
      containers:
      - name: myapp
        image: myapp:production
        ports:
        - containerPort: 80
        env:
        - name: APP_ENV
          value: production
        livenessProbe:
          httpGet:
            path: /
            port: 80
          initialDelaySeconds: 40
          periodSeconds: 30
```

### Cloud Platforms

**AWS ECS, Google Cloud Run, Azure Container Instances**:
- All support this image out of the box
- Configure environment variables via platform settings
- Use managed databases (RDS, Cloud SQL, etc.)

## Health Checks

The Dockerfile includes a health check:

```dockerfile
HEALTHCHECK --interval=30s --timeout=3s --start-period=40s --retries=3 \
    CMD curl -f http://localhost/ || exit 1
```

Check health status:
```bash
docker ps  # Look at STATUS column
docker inspect --format='{{.State.Health.Status}}' myapp
```

## Monitoring

### Check OPcache Statistics

```bash
docker exec myapp php -r "print_r(opcache_get_status());"
```

### View PHP Configuration

```bash
docker exec myapp php -i | less
```

### Container Logs

```bash
docker logs -f myapp
```

## Performance Tuning

### Tune OPcache for Your Application

1. **Calculate max_accelerated_files**:
   ```bash
   # Count PHP files in your app
   find /var/www/html -name "*.php" | wc -l
   # Set to ~2x this number
   ```

2. **Adjust memory consumption**:
   - Start with 256MB
   - Monitor usage: `opcache_get_status()['memory_usage']`
   - Increase if needed

3. **Interned strings buffer**:
   - For large applications: 16-32
   - For small applications: 8

### Apache Tuning

Add to Dockerfile or set via environment:

```dockerfile
ENV APACHE_MAX_CONNECTIONS=150
ENV APACHE_KEEPALIVE=On
ENV APACHE_KEEPALIVE_TIMEOUT=5
```

## CI/CD Integration

### GitHub Actions

```yaml
name: Build and Deploy

on:
  push:
    branches: [ main ]

jobs:
  build:
    runs-on: ubuntu-latest
    steps:
    - uses: actions/checkout@v3

    - name: Build Docker image
      run: docker build -t myapp:${{ github.sha }} .

    - name: Run tests
      run: docker run --rm myapp:${{ github.sha }} ./vendor/bin/phpunit

    - name: Push to registry
      run: |
        echo ${{ secrets.DOCKER_PASSWORD }} | docker login -u ${{ secrets.DOCKER_USERNAME }} --password-stdin
        docker tag myapp:${{ github.sha }} myregistry/myapp:latest
        docker push myregistry/myapp:latest
```

### GitLab CI

```yaml
build:
  stage: build
  image: docker:latest
  services:
    - docker:dind
  script:
    - docker build -t $CI_REGISTRY_IMAGE:$CI_COMMIT_SHA .
    - docker push $CI_REGISTRY_IMAGE:$CI_COMMIT_SHA
```

## Scaling Considerations

### Horizontal Scaling

This image is **stateless** and can be scaled horizontally:

```bash
# Docker Swarm
docker service scale myapp=5

# Kubernetes
kubectl scale deployment myapp --replicas=5
```

### Session Storage

For multi-instance deployments, use Redis for sessions:

```php
// config/session.php (Laravel)
'driver' => env('SESSION_DRIVER', 'redis'),
```

## Troubleshooting

### OPcache Not Working

Check if enabled:
```bash
docker exec myapp php -r "echo opcache_get_status() ? 'Enabled' : 'Disabled';"
```

### Image Too Large

1. Check layer sizes:
   ```bash
   docker history myapp:production
   ```

2. Use `.dockerignore`:
   ```
   .git
   .env
   node_modules
   vendor
   tests
   *.log
   ```

3. Remove dev dependencies:
   ```bash
   composer install --no-dev
   ```

### High Memory Usage

Monitor container:
```bash
docker stats myapp
```

Reduce OPcache:
```dockerfile
ENV PHP_INI_OPCACHE__MEMORY_CONSUMPTION=128
```

## Best Practices Checklist

- ✅ Use slim image for production
- ✅ Enable OPcache with `validate_timestamps=0`
- ✅ Disable error display, enable error logging
- ✅ Install only required extensions
- ✅ Use `--no-dev` for composer
- ✅ Optimize autoloader
- ✅ Set proper file permissions
- ✅ Include health checks
- ✅ Use `.dockerignore`
- ✅ Tag images with version/commit SHA
- ✅ Run as non-root user (handled by image)
- ✅ Use environment variables for configuration

## References

- [Main README](../../README.md)
- [Architecture Documentation](../../ARCHITECTURE.md)
- [Troubleshooting Guide](../../TROUBLESHOOTING.md)
- [PHP OPcache Documentation](https://www.php.net/manual/en/book.opcache.php)

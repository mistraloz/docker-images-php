# Architecture Documentation

This document explains the internal architecture and design of the thecodingmachine PHP Docker images project.

## Table of Contents

- [Overview](#overview)
- [Project Structure](#project-structure)
- [Image Generation System](#image-generation-system)
- [Extension Management System](#extension-management-system)
- [Startup Process](#startup-process)
- [Environment Variable Processing](#environment-variable-processing)
- [Build System](#build-system)
- [Testing Infrastructure](#testing-infrastructure)

---

## Overview

This project uses a **template-based code generation** approach to maintain multiple Docker images efficiently. Instead of manually maintaining hundreds of Dockerfiles, we maintain a few blueprint templates and generate all variations automatically.

### Key Design Principles

1. **DRY (Don't Repeat Yourself)**: Use templates to avoid duplication
2. **Separation of Concerns**: Extension installation logic is separate from image configuration
3. **Runtime Flexibility**: Enable/disable extensions and configure PHP without rebuilding
4. **Multi-platform Support**: Build for both amd64 and arm64 architectures

---

## Project Structure

```
docker-images-php/
├── utils/                      # Blueprint templates and scripts
│   ├── *.blueprint             # Dockerfile templates (source of truth)
│   ├── README.blueprint.md     # README template
│   ├── docker-bake.blueprint.hcl  # Build config template
│   ├── docker-entrypoint*.sh   # Container startup scripts
│   └── *.php                   # PHP helper scripts
│
├── extensions/                 # PHP extension installation scripts
│   ├── core/                   # Base extension scripts (shared)
│   │   ├── amqp/              # Each extension has its own directory
│   │   │   └── install.sh     # Installation script
│   │   ├── install_all.sh     # Install all extensions (fat image)
│   │   └── disable_all.sh     # Disable all extensions (fat image)
│   └── [7.2, 7.3, 7.4, 8.0, 8.1, 8.2]/  # Version-specific symlinks
│
├── Dockerfile.*               # Generated Dockerfiles (DO NOT EDIT)
├── docker-bake.hcl           # Generated build config (DO NOT EDIT)
├── README.md                 # Generated README (DO NOT EDIT)
│
├── tests-suite/              # Automated testing
│   └── *.sh                  # Test scripts
│
└── orbit.yml                 # Orbit tasks (template processor)
```

### Source Files vs Generated Files

| Type | Location | Editable |
|------|----------|----------|
| Templates (blueprints) | `utils/*.blueprint` | ✅ YES |
| Generated Dockerfiles | `Dockerfile.*` | ❌ NO |
| Generated README | `README.md` | ❌ NO |
| Generated build config | `docker-bake.hcl` | ❌ NO |
| Extension scripts | `extensions/core/*/install.sh` | ✅ YES |
| Utility scripts | `utils/*.sh`, `utils/*.php` | ✅ YES |

**Important**: All Dockerfiles, README.md, and docker-bake.hcl are auto-generated. Edit the `.blueprint` files instead!

---

## Image Generation System

### Orbit Template Engine

We use [Orbit](https://github.com/gulien/orbit) to generate files from templates.

**Template Variables** (defined in `orbit.yml`):

```yaml
Orbit:
  Images:
    php_version: "8.2"  # Current PHP version being generated
```

**Template Syntax** (in `*.blueprint` files):

```
{{ .Orbit.Images.php_version }}  # Variable interpolation
{{ range $version := list "8.2" "8.1" "8.0" }}  # Loops
{{ if eq $version "8.2" }}  # Conditionals
```

### Generation Process

```
utils/Dockerfile.blueprint
utils/Dockerfile.slim.blueprint     →  [Orbit processing]  →  Dockerfile.apache
utils/Dockerfile.node.blueprint                                Dockerfile.cli
utils/README.blueprint.md                                      Dockerfile.fpm
utils/docker-bake.blueprint.hcl                                Dockerfile.*.node
                                                               Dockerfile.slim.*
                                                               README.md
                                                               docker-bake.hcl
```

**To regenerate all files:**

```bash
make generate
# Or directly:
orbit run generate
```

### Image Variants Matrix

The build system generates images for all combinations:

- **PHP versions**: 7.2, 7.3, 7.4, 8.0, 8.1, 8.2
- **Types**: fat, slim
- **Variants**: cli, apache, fpm
- **Node versions** (optional): 10, 12, 14, 16, 18
- **Architectures**: amd64, arm64

**Total images**: ~100+ variants

---

## Extension Management System

### How Extensions Are Organized

Each PHP extension has its own directory under `extensions/core/`:

```
extensions/core/redis/
├── install.sh         # Installation script
└── (optional files)   # Config files, patches, etc.
```

### Extension Installation Script Structure

Every `install.sh` follows this pattern:

```bash
#!/bin/bash
set -ex

# Install system dependencies via apt
sudo apt-get install -y libsomething-dev

# Install PHP extension
# Method 1: Using apt (preferred)
sudo apt-get install -y php${PHP_VERSION}-redis

# Method 2: Using PECL/Pickle
sudo pickle install redis

# Method 3: Compile from source
# cd /path/to/source && phpize && ./configure && make && sudo make install
```

### Version-Specific Extensions

PHP version directories (`extensions/7.4/`, `extensions/8.0/`, etc.) contain **symlinks** to `core/`:

```
extensions/8.0/redis -> ../core/redis
```

This allows:
1. Shared installation logic in `core/`
2. Version-specific overrides when needed
3. Easy addition/removal of extensions per PHP version

### Extension Loading in Fat Images

**Build time** (`Dockerfile.apache`, `Dockerfile.cli`, `Dockerfile.fpm`):

```dockerfile
# Install ALL available extensions
RUN /usr/local/bin/install-extensions /extensions/8.2/install_all.sh

# Then disable them all by default
RUN /extensions/8.2/disable_all.sh
```

**Runtime** (container startup):
- Extensions are enabled based on `PHP_EXTENSION_*` environment variables
- See [Startup Process](#startup-process) below

### Extension Loading in Slim Images

**Build time** uses an `ONBUILD` trigger:

```dockerfile
ONBUILD ARG PHP_EXTENSIONS
ONBUILD RUN if [ ! -z "$PHP_EXTENSIONS" ]; then \
    /usr/local/bin/install-extensions $PHP_EXTENSIONS; \
fi
```

**User's Dockerfile**:

```dockerfile
ARG PHP_EXTENSIONS="mysqli redis"
FROM thecodingmachine/php:8.2-v4-slim-apache
# ONBUILD trigger runs here automatically
```

---

## Startup Process

Every container goes through this startup sequence:

### 1. Entrypoint Script (`docker-entrypoint.sh`)

Located at `/usr/local/bin/docker-entrypoint.sh`, this is the main entrypoint.

**Key responsibilities:**
- Set up user permissions
- Process environment variables
- Configure PHP and Apache
- Run startup commands
- Start the main service (Apache/PHP-FPM/PHP CLI)

### 2. User Permission Setup

```bash
# Check DOCKER_USER_UID and DOCKER_USER_GID
if [ -n "$DOCKER_USER_UID" ]; then
    sudo usermod -u $DOCKER_USER_UID docker
fi
if [ -n "$DOCKER_USER_GID" ]; then
    sudo groupmod -g $DOCKER_USER_GID docker
fi
```

This solves Docker file permission issues by matching container user to host user.

### 3. Extension Configuration

**Script**: `utils/generate-extensions-config.php`

```php
// Reads PHP_EXTENSION_* environment variables
// Generates /usr/local/etc/php/conf.d/generated-conf.ini
```

**Example**:

```bash
# Environment variables
PHP_EXTENSION_REDIS=1
PHP_EXTENSION_XDEBUG=1
PHP_EXTENSION_MYSQLI=0

# Generated config
extension=redis.so
zend_extension=xdebug.so
; extension=mysqli.so (disabled)
```

### 4. PHP Configuration

**Script**: `utils/generate-php-config.php`

Reads `PHP_INI_*` environment variables and generates `/usr/local/etc/php/conf.d/generated-conf.ini`:

```bash
# Environment
PHP_INI_MEMORY_LIMIT=512M
PHP_INI_MAX_EXECUTION_TIME=300
PHP_INI_XDEBUG__MODE=debug

# Generated php.ini
memory_limit = 512M
max_execution_time = 300

[xdebug]
xdebug.mode = debug
```

**Pattern**: `PHP_INI_<SECTION>__<KEY>` or `PHP_INI_<KEY>`

### 5. Apache Configuration (apache variant only)

**Script**: `utils/generate-apache-config.php`

Reads `APACHE_*` environment variables:

```bash
APACHE_DOCUMENT_ROOT=/var/www/html/public
APACHE_ALLOW_OVERRIDE=All
```

Generates Apache config adjustments.

### 6. Cron Jobs (fat images only)

**Script**: `utils/generate-cron-config.php`

Reads `CRON_SCHEDULE_*` and `CRON_COMMAND_*` pairs:

```bash
CRON_SCHEDULE_1="* * * * *"
CRON_COMMAND_1="php /var/www/html/artisan schedule:run"
```

Generates Supercronic crontab file.

### 7. Startup Commands

Executes custom commands in order:

```bash
STARTUP_COMMAND_1="composer install"
STARTUP_COMMAND_2="php artisan migrate"
```

### 8. Start Main Service

Finally, starts the appropriate service:

- **Apache variant**: `apache2-foreground`
- **FPM variant**: `php-fpm`
- **CLI variant**: `bash` or custom command

---

## Environment Variable Processing

### Naming Conventions

| Pattern | Purpose | Example |
|---------|---------|---------|
| `PHP_EXTENSION_<NAME>` | Enable/disable extension | `PHP_EXTENSION_REDIS=1` |
| `PHP_EXTENSIONS` | Space-separated extension list | `PHP_EXTENSIONS="redis mysqli"` |
| `PHP_INI_<KEY>` | Set php.ini value | `PHP_INI_MEMORY_LIMIT=256M` |
| `PHP_INI_<SECTION>__<KEY>` | Set sectioned ini value | `PHP_INI_OPCACHE__ENABLE=1` |
| `APACHE_<KEY>` | Apache configuration | `APACHE_DOCUMENT_ROOT=/app/public` |
| `CRON_SCHEDULE_N` | Cron schedule | `CRON_SCHEDULE_1="0 * * * *"` |
| `CRON_COMMAND_N` | Cron command | `CRON_COMMAND_1="php backup.php"` |
| `STARTUP_COMMAND_N` | Startup command | `STARTUP_COMMAND_1="composer install"` |

### Processing Flow

```
Container Start
     │
     ├─→ Read PHP_EXTENSION_* env vars
     │   └─→ generate-extensions-config.php
     │       └─→ /usr/local/etc/php/conf.d/generated-conf.ini
     │
     ├─→ Read PHP_INI_* env vars
     │   └─→ generate-php-config.php
     │       └─→ /usr/local/etc/php/conf.d/generated-conf.ini (appended)
     │
     ├─→ Read APACHE_* env vars
     │   └─→ generate-apache-config.php
     │       └─→ /etc/apache2/sites-enabled/000-default.conf (modified)
     │
     ├─→ Read CRON_* env vars
     │   └─→ generate-cron-config.php
     │       └─→ /etc/cron.d/crontab
     │
     └─→ Execute STARTUP_COMMAND_* in order
```

---

## Build System

### Docker Buildx and Bake

We use [Docker Buildx Bake](https://docs.docker.com/build/bake/) for multi-platform builds.

**Configuration**: `docker-bake.hcl` (generated from `utils/docker-bake.blueprint.hcl`)

**Features**:
- Multi-platform builds (amd64, arm64)
- Parallel building
- Layer caching
- Multiple target definitions

**Build targets**:

```hcl
target "php-8.2-apache" {
  context = "."
  dockerfile = "Dockerfile.apache"
  tags = ["thecodingmachine/php:8.2-v4-apache"]
  platforms = ["linux/amd64", "linux/arm64"]
}
```

### Building Images

**Build all images**:
```bash
docker buildx bake -f docker-bake.hcl
```

**Build specific image**:
```bash
docker buildx bake -f docker-bake.hcl php-8.2-apache
```

**Build for specific platform**:
```bash
docker buildx bake -f docker-bake.hcl --set "*.platform=linux/amd64" php-8.2-apache
```

### Makefile Targets

```bash
make generate        # Generate all files from blueprints
make build           # Build Docker images
make test           # Run tests
make publish        # Publish images to Docker Hub
```

---

## Testing Infrastructure

### Test Framework

Uses [bash_unit](https://github.com/pgrange/bash_unit) - a bash unit testing framework.

**Test files**: `tests-suite/*.sh`

### Test Types

1. **Extension tests** (`test_extensions.sh`):
   - Test each extension can be enabled
   - Verify extension loads correctly
   - Test version-specific extensions

2. **Configuration tests** (`test_ini.sh`):
   - Test `PHP_INI_*` variables work
   - Test php.ini generation

3. **Apache tests** (`test_apache.sh`):
   - Test document root configuration
   - Test .htaccess processing

4. **Xdebug tests** (`test_xdebug.sh`):
   - Test Xdebug can be enabled
   - Test Xdebug configuration

5. **Cron tests** (`test_cron.sh`):
   - Test cron job generation

### Running Tests

```bash
# Run all tests
make test

# Run specific test file
./tests-suite/bash_unit tests-suite/test_extensions.sh

# Run tests in Docker
docker run --rm thecodingmachine/php:8.2-v4-apache /tests-suite/bash_unit /tests-suite/test_*.sh
```

### CI/CD Pipeline

**GitHub Actions**: `.github/workflows/workflow.yml`

**Workflow**:
1. Trigger on push, PR, or schedule (weekly)
2. Build images for all variants
3. Run test suite against built images
4. If tests pass and on main branch, push to Docker Hub

---

## Extension Development Guide

### Adding a New Extension

**Example: Adding the `rdkafka` extension**

1. **Create extension directory**:
   ```bash
   mkdir -p extensions/core/rdkafka
   ```

2. **Create install.sh**:
   ```bash
   #!/bin/bash
   set -ex

   # Install system dependencies
   sudo apt-get install -y librdkafka-dev

   # Install PHP extension
   sudo pickle install rdkafka
   ```

3. **Make executable**:
   ```bash
   chmod +x extensions/core/rdkafka/install.sh
   ```

4. **Create symlinks for PHP versions**:
   ```bash
   cd extensions/8.2 && ln -s ../core/rdkafka rdkafka
   cd extensions/8.1 && ln -s ../core/rdkafka rdkafka
   # etc...
   ```

5. **Update fat image install list**:
   Edit `extensions/core/install_all.sh` to include the new extension.

6. **Test**:
   ```bash
   docker build -f Dockerfile.apache -t test .
   docker run --rm -e PHP_EXTENSION_RDKAFKA=1 test php -m | grep rdkafka
   ```

### Extension Compatibility

Some extensions are not available on all platforms/versions:

**Check availability**:
```bash
apt-cache search php8.2-rdkafka
```

**Version-specific extensions**:

If an extension is only available in certain PHP versions, create symlinks only for those versions:

```bash
# rdkafka not available in PHP 7.2
cd extensions/7.3 && ln -s ../core/rdkafka rdkafka
cd extensions/7.4 && ln -s ../core/rdkafka rdkafka
# etc...
```

---

## Performance Optimizations

### Build Time Optimizations

1. **Layer caching**: Extension installation is done in separate layers
2. **Parallel builds**: BuildKit builds images in parallel
3. **Multi-stage builds**: Slim images use multi-stage for smaller final images

### Runtime Optimizations

1. **Extension lazy loading**: Extensions installed but not loaded until enabled
2. **OPcache**: Can be enabled via `PHP_INI_OPCACHE__ENABLE=1`
3. **Precompiled extensions**: Fat images have extensions pre-compiled

### Image Size Optimizations

1. **Slim images**: Only essential extensions
2. **apt cleanup**: Build scripts remove apt cache after installation
3. **Layer squashing**: Consider using `--squash` for production builds

---

## Contributing to the Project

### Workflow

1. **Make changes in blueprints**: Edit files in `utils/*.blueprint`
2. **Regenerate**: Run `make generate`
3. **Test locally**: Build and test images
4. **Submit PR**: With clear description of changes

### Best Practices

- ✅ Edit blueprint files, not generated files
- ✅ Test on both amd64 and arm64 if possible
- ✅ Update documentation when adding features
- ✅ Add tests for new extensions or features
- ✅ Follow existing code style

---

## Architecture Diagrams

### Image Hierarchy

```
ubuntu:20.04
    │
    ├─→ php:8.2-cli-ubuntu (base)
    │     │
    │     ├─→ thecodingmachine/php:8.2-v4-slim-cli (minimal)
    │     │     │
    │     │     └─→ thecodingmachine/php:8.2-v4-cli (fat, all extensions)
    │     │
    │     ├─→ thecodingmachine/php:8.2-v4-slim-apache
    │     │     │
    │     │     └─→ thecodingmachine/php:8.2-v4-apache (fat)
    │     │           │
    │     │           └─→ thecodingmachine/php:8.2-v4-apache-node18 (fat + NodeJS)
    │     │
    │     └─→ thecodingmachine/php:8.2-v4-slim-fpm
    │           │
    │           └─→ thecodingmachine/php:8.2-v4-fpm (fat)
    │                 │
    │                 └─→ thecodingmachine/php:8.2-v4-fpm-node18 (fat + NodeJS)
```

### Startup Sequence Diagram

```
Container Start
      │
      ├─→ docker-entrypoint.sh
      │      │
      │      ├─→ Setup user permissions
      │      │      (usermod/groupmod based on DOCKER_USER_UID/GID)
      │      │
      │      ├─→ generate-extensions-config.php
      │      │      (process PHP_EXTENSION_* variables)
      │      │
      │      ├─→ generate-php-config.php
      │      │      (process PHP_INI_* variables)
      │      │
      │      ├─→ generate-apache-config.php (apache variant)
      │      │      (process APACHE_* variables)
      │      │
      │      ├─→ generate-cron-config.php (fat images)
      │      │      (process CRON_* variables)
      │      │
      │      ├─→ Execute STARTUP_COMMAND_1, 2, 3...
      │      │
      │      └─→ Start main service
      │             │
      │             ├─→ Apache (apache variant)
      │             ├─→ PHP-FPM (fpm variant)
      │             └─→ bash/cmd (cli variant)
      │
      └─→ Application Running
```

---

## Conclusion

This architecture enables:
- ✅ Maintaining 100+ image variants efficiently
- ✅ Flexible runtime configuration
- ✅ Easy addition of new extensions
- ✅ Multi-platform support
- ✅ Developer-friendly workflow

Understanding this architecture helps you:
- Contribute to the project
- Debug issues effectively
- Customize images for your needs
- Optimize builds and runtime performance

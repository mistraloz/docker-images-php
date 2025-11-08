# Developer Help & Tips

This document provides tips, tricks, and development guidance for contributors and advanced users.

## Table of Contents

- [Development TODO List](#development-todo-list)
- [Testing Extensions](#testing-extensions)
- [Development Workflow](#development-workflow)
- [Debugging Tips](#debugging-tips)
- [Contributing Guidelines](#contributing-guidelines)
- [Useful Resources](#useful-resources)

---

## Development TODO List

These are planned improvements for the project:

* [ ] Script to test all available extensions in one pass
* [ ] BuildKit optimization guide - document advanced usage of `docker buildx bake`
* [ ] Image size optimization - reduce fat image sizes
* [ ] Document tooling for creating packaged apps with slim images
* [ ] Automated extension compatibility matrix
* [ ] Performance benchmarking suite

**Want to contribute?** Pick one of these tasks! See [CONTRIBUTING.md](.github/CONTRIBUTING.md) for guidelines.

---

## Testing Extensions

### How to Test Extension Availability

To check if a PHP extension is available in the repositories:

1. **Build or pull the slim image**:
   ```bash
   docker pull thecodingmachine/php:8.2-v4-slim-apache
   ```

2. **Run interactive shell with sudo**:
   ```bash
   docker run -it --rm thecodingmachine/php:8.2-v4-slim-apache sudo bash
   ```

3. **Update apt cache and search for extension**:
   ```bash
   apt-get update
   apt-cache search --names-only php8.2-zip
   apt-cache search --names-only php8.2-redis
   ```

4. **Check extension details**:
   ```bash
   apt-cache show php8.2-redis
   ```

**Important**: Some extensions are installed via [Pickle](https://github.com/FriendsOfPHP/pickle) instead of apt packages. These won't appear in apt search results.

### Extensions Installed via Pickle

Extensions not available as apt packages are installed using Pickle:

- `grpc`
- `swoole`
- `ast`
- Some others depending on PHP version

To check Pickle installation scripts, look at:
```bash
cat extensions/core/grpc/install.sh
```

### Testing Individual Extensions

**Test in fat image**:

```bash
docker run --rm \
  -e PHP_EXTENSION_REDIS=1 \
  thecodingmachine/php:8.2-v4-cli \
  php -m | grep redis
```

**Test in slim image** (requires build):

```dockerfile
ARG PHP_EXTENSIONS="redis"
FROM thecodingmachine/php:8.2-v4-slim-cli
```

```bash
docker build -t test-redis -f Dockerfile.test .
docker run --rm test-redis php -m | grep redis
```

### Compare Extensions Between PHP Versions

To see which extensions differ between PHP versions:

```bash
# Compare PHP 8.2 to core
diff -q ./extensions/core ./extensions/8.2

# Compare PHP 8.1 to PHP 8.2
diff -q ./extensions/8.1 ./extensions/8.2

# Detailed comparison
diff -r ./extensions/8.1 ./extensions/8.2
```

### Testing All Extensions (WIP)

Currently there's no automated script to test all extensions. This is a **TODO** item!

Proposed approach:
```bash
# Future script (not implemented yet)
./tests-suite/test_all_extensions.sh 8.2-v4-apache
```

**Want to help?** Implement this script! See [Development TODO List](#development-todo-list).

---

## Development Workflow

### Setting Up Development Environment

1. **Clone the repository**:
   ```bash
   git clone https://github.com/thecodingmachine/docker-images-php.git
   cd docker-images-php
   ```

2. **Install Orbit** (template generator):
   ```bash
   # On Linux/macOS
   curl -sSL "https://github.com/gulien/orbit/releases/download/v3.0.1/orbit_3.0.1_linux_amd64.tar.gz" | tar -xz
   sudo mv orbit /usr/local/bin/

   # On Windows
   # Download from https://github.com/gulien/orbit/releases
   ```

3. **Verify Orbit installation**:
   ```bash
   orbit --version
   ```

### Making Changes

1. **Edit blueprint templates** (NOT generated files):
   ```bash
   # Edit these
   vim utils/Dockerfile.blueprint
   vim utils/README.blueprint.md

   # DON'T edit these (they're auto-generated)
   # Dockerfile.apache
   # README.md
   ```

2. **Regenerate files from blueprints**:
   ```bash
   make generate
   # Or
   orbit run generate
   ```

3. **Build images locally**:
   ```bash
   # Build specific variant
   docker build -f Dockerfile.apache -t test:local .

   # Build using buildx bake
   docker buildx bake -f docker-bake.hcl php-8.2-apache
   ```

4. **Test your changes**:
   ```bash
   # Run tests
   make test

   # Or run specific test
   ./tests-suite/bash_unit tests-suite/test_extensions.sh
   ```

### Adding a New Extension

See [ARCHITECTURE.md - Extension Development Guide](ARCHITECTURE.md#extension-development-guide) for detailed instructions.

**Quick checklist**:
1. Create `extensions/core/myext/install.sh`
2. Make it executable: `chmod +x extensions/core/myext/install.sh`
3. Create symlinks in version directories: `ln -s ../core/myext extensions/8.2/myext`
4. Add to `extensions/core/install_all.sh` (for fat images)
5. Test installation
6. Submit PR

### Adding a New PHP Version

When a new PHP version is released (e.g., PHP 8.3):

1. **Update blueprint templates**:
   ```
   # In utils/README.blueprint.md and utils/docker-bake.blueprint.hcl
   {{ $versions := list "8.3" "8.2" "8.1" "8.0" "7.4" }}
   ```

2. **Create extension symlinks**:
   ```bash
   mkdir extensions/8.3
   cd extensions/8.3
   # Create symlinks to all compatible extensions from core/
   ```

3. **Update Dockerfiles**:
   - Check PHP 8.3 base image is available
   - Update base image references in blueprints

4. **Regenerate all files**:
   ```bash
   make generate
   ```

5. **Test thoroughly**:
   ```bash
   make test
   ```

---

## Debugging Tips

### Enable Verbose Output

**During build**:
```bash
docker build --progress=plain --no-cache -f Dockerfile.apache .
```

**During container startup**:
```bash
docker run --rm -e DEBUG=1 thecodingmachine/php:8.2-v4-apache
```

### Inspect Running Container

```bash
# Open shell in running container
docker exec -it <container-name> bash

# Check PHP configuration
php -i | less
php -m  # List loaded modules

# Check generated config files
cat /usr/local/etc/php/conf.d/generated-conf.ini

# Check Apache config (apache variant)
cat /etc/apache2/sites-enabled/000-default.conf

# View environment variables
env | grep PHP
```

### Check Image Layers

```bash
# Inspect image
docker history thecodingmachine/php:8.2-v4-apache

# Dive tool (recommended for detailed analysis)
dive thecodingmachine/php:8.2-v4-apache
```

### Debug Extension Loading

```bash
# List all .so files
docker run --rm thecodingmachine/php:8.2-v4-apache find /usr/lib/php -name "*.so"

# Check if extension .ini files exist
docker run --rm thecodingmachine/php:8.2-v4-apache ls -la /usr/local/etc/php/conf.d/

# Test extension loading with error reporting
docker run --rm thecodingmachine/php:8.2-v4-apache \
  php -d display_errors=1 -d error_reporting=E_ALL -m
```

### Test Entrypoint Scripts

```bash
# Run entrypoint manually
docker run --rm -it thecodingmachine/php:8.2-v4-apache bash
/usr/local/bin/docker-entrypoint.sh
```

---

## Contributing Guidelines

### Code Style

- **Shell scripts**: Follow [Google Shell Style Guide](https://google.github.io/styleguide/shellguide.html)
- **PHP scripts**: Follow PSR-12
- **Dockerfiles**: Use multi-line format for readability

### Commit Messages

Follow [Conventional Commits](https://www.conventionalcommits.org/):

```
feat: add support for rdkafka extension
fix: correct xdebug configuration generation
docs: improve QUICKSTART guide
refactor: simplify extension install scripts
test: add tests for PHP 8.3
```

### Pull Request Process

1. Fork the repository
2. Create a feature branch: `git checkout -b feat/my-feature`
3. Make your changes in blueprint files
4. Regenerate files: `make generate`
5. Test locally: `make test`
6. Commit with clear messages
7. Push to your fork
8. Create PR with description of changes

See [.github/CONTRIBUTING.md](.github/CONTRIBUTING.md) for full guidelines.

---

## Useful Resources

### PHP Extension Information

- [PHP Extension Repository Status (Remi's Blog)](https://blog.remirepo.net/post/2020/09/21/PHP-extensions-status-with-upcoming-PHP-8.0)
- [PECL Extensions](https://pecl.php.net/)
- [PHP Manual - Extensions](https://www.php.net/manual/en/extensions.php)

### Docker Best Practices

- [Docker Best Practices](https://docs.docker.com/develop/dev-best-practices/)
- [Dockerfile Best Practices](https://docs.docker.com/develop/develop-images/dockerfile_best-practices/)
- [Docker Buildx Bake Reference](https://docs.docker.com/build/bake/)

### Tools

- [Orbit](https://github.com/gulien/orbit) - Template engine used in this project
- [Pickle](https://github.com/FriendsOfPHP/pickle) - PHP extension installer
- [Supercronic](https://github.com/aptible/supercronic) - Cron for containers
- [bash_unit](https://github.com/pgrange/bash_unit) - Testing framework
- [Dive](https://github.com/wagoodman/dive) - Docker image layer inspector

### Related Projects

- [Official PHP Docker Images](https://hub.docker.com/_/php)
- [PHP on Alpine](https://github.com/codecasts/php-alpine)

---

## Getting Help

If you need help:

1. **Check documentation**:
   - [README.md](README.md) - Main documentation
   - [QUICKSTART.md](QUICKSTART.md) - Quick start guide
   - [TROUBLESHOOTING.md](TROUBLESHOOTING.md) - Common issues
   - [ARCHITECTURE.md](ARCHITECTURE.md) - Internal architecture

2. **Search existing issues**:
   - https://github.com/thecodingmachine/docker-images-php/issues

3. **Ask a question**:
   - Open a new issue with the "question" label

4. **Join the discussion**:
   - GitHub Discussions (if enabled)

---

## Maintenance Notes

### Weekly Tasks

- [ ] Check for new PHP patch releases
- [ ] Review and merge dependabot PRs
- [ ] Monitor image sizes
- [ ] Review open issues

### Monthly Tasks

- [ ] Update base images
- [ ] Review extension compatibility
- [ ] Update documentation
- [ ] Performance benchmarks

### Before Major Releases

- [ ] Test all image variants
- [ ] Update CHANGELOG.md
- [ ] Update MIGRATING.md if breaking changes
- [ ] Tag release
- [ ] Push to Docker Hub
- [ ] Create GitHub release

---

## Tips & Tricks

### Faster Local Builds

Use BuildKit with cache:

```bash
DOCKER_BUILDKIT=1 docker build \
  --build-arg BUILDKIT_INLINE_CACHE=1 \
  --cache-from thecodingmachine/php:8.2-v4-apache \
  -t test:local -f Dockerfile.apache .
```

### Multi-Platform Builds

```bash
# Setup buildx
docker buildx create --use --name multiarch

# Build for both platforms
docker buildx build \
  --platform linux/amd64,linux/arm64 \
  -f Dockerfile.apache \
  -t myregistry/php:8.2-apache \
  --push .
```

### Quick Extension Testing

```bash
# One-liner to test extension
docker run --rm \
  -e PHP_EXTENSION_REDIS=1 \
  thecodingmachine/php:8.2-v4-apache \
  php -r "echo extension_loaded('redis') ? 'OK' : 'FAIL';"
```

### Generate Extension List

```bash
# List all available extensions
ls -1 extensions/8.2/ | sort

# Count extensions
ls -1 extensions/8.2/ | wc -l
```

---

**Happy coding! 🚀**
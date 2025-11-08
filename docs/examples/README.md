# Docker PHP Images - Practical Examples

This directory contains ready-to-use examples for common use cases.

## Available Examples

### Web Frameworks

- [Laravel Application](laravel/) - Complete Laravel setup with MySQL and Redis
- [Symfony Application](symfony/) - Symfony with PostgreSQL
- [WordPress](wordpress/) - WordPress with MySQL and WP-CLI

### Development Environments

- [Full-Stack Development](fullstack/) - PHP 8.2 + Node.js 18 + PostgreSQL
- [Microservices](microservices/) - Multiple PHP services with shared dependencies
- [Legacy Application](legacy/) - PHP 7.4 application upgrade path

### Production Deployments

- [Production Slim Image](production-slim/) - Optimized production build
- [Multi-Stage Build](multi-stage/) - Development and production in one Dockerfile
- [Docker Swarm](docker-swarm/) - Swarm deployment configuration

### Specific Use Cases

- [Background Workers](background-workers/) - Cron jobs and queue workers
- [Testing Environment](testing/) - PHPUnit tests in CI/CD
- [Xdebug Setup](xdebug/) - Debug configuration for various IDEs
- [Custom Extensions](custom-extensions/) - Building slim image with specific extensions

## How to Use These Examples

Each example contains:
- `README.md` - Explanation and instructions
- `docker-compose.yml` or `Dockerfile` - Ready-to-use configuration
- Sample application code (when applicable)

To try an example:

```bash
cd examples/laravel/
docker-compose up
```

## Contributing Examples

Have a useful configuration? Submit a PR with:
1. New directory in `examples/`
2. Working `docker-compose.yml` or `Dockerfile`
3. `README.md` explaining the setup
4. Any necessary application code

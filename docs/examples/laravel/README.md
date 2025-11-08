# Laravel Application Example

Complete Laravel development environment with MySQL, Redis, queue workers, and scheduler.

## What's Included

- **Laravel App** (PHP 8.2 + Apache)
- **MySQL 8.0** database
- **Redis** for caching and queues
- **Queue Worker** for background jobs
- **Scheduler** for Laravel's task scheduling

## Quick Start

1. **Create a new Laravel project** or copy your existing one:

```bash
# Create new Laravel project
composer create-project laravel/laravel app
cd app
```

2. **Start the environment**:

```bash
docker-compose up -d
```

3. **Access your application**:
   - Web: http://localhost:8000
   - Database: localhost:3306
   - Redis: localhost:6379

## Features Demonstrated

### PHP Extensions

The following extensions are enabled:
- `pdo_mysql` - MySQL database connection
- `redis` - Redis support
- `gd` - Image manipulation
- `intl` - Internationalization

### Apache Configuration

- Custom document root: `/var/www/html/public` (Laravel's public directory)
- Configured for Laravel's routing

### PHP Configuration

- Memory limit: 256M
- Upload max filesize: 50M
- Post max size: 50M
- Max execution time: 300s

### Background Processing

**Queue Worker Container**:
- Runs `php artisan queue:work`
- Processes jobs from Redis
- Automatic restart on failure

**Scheduler Container**:
- Runs Laravel's scheduler every minute
- Uses cron via `CRON_SCHEDULE_*` environment variables

### Database Migrations

Migrations run automatically on container startup via `STARTUP_COMMAND_1`.

## File Permissions

The container runs as UID 1000 / GID 1000 by default. Adjust if needed:

```yaml
environment:
  DOCKER_USER_UID: 1000  # Change to your user ID
  DOCKER_USER_GID: 1000  # Change to your group ID
```

To find your UID/GID:
```bash
id -u  # UID
id -g  # GID
```

## Common Tasks

### Install Dependencies

```bash
docker-compose exec app composer install
```

### Run Artisan Commands

```bash
docker-compose exec app php artisan migrate
docker-compose exec app php artisan make:controller UserController
docker-compose exec app php artisan tinker
```

### Access Container Shell

```bash
docker-compose exec app bash
```

### View Logs

```bash
# All logs
docker-compose logs -f

# Specific service
docker-compose logs -f app
docker-compose logs -f queue
```

### Clear Cache

```bash
docker-compose exec app php artisan cache:clear
docker-compose exec app php artisan config:clear
docker-compose exec app php artisan route:clear
docker-compose exec app php artisan view:clear
```

## Production Deployment

For production, consider:

1. **Use slim image** with only required extensions
2. **Disable debug mode**:
   ```yaml
   environment:
     APP_ENV: production
     APP_DEBUG: "false"
   ```
3. **Optimize autoloader**:
   ```bash
   composer install --optimize-autoloader --no-dev
   ```
4. **Cache configuration**:
   ```bash
   php artisan config:cache
   php artisan route:cache
   php artisan view:cache
   ```

See the [production-slim](../production-slim/) example for a complete production setup.

## Troubleshooting

### Permission Denied Errors

Make sure `DOCKER_USER_UID` and `DOCKER_USER_GID` match your host user:

```bash
docker-compose down
# Update docker-compose.yml with your UID/GID
docker-compose up -d
```

### Database Connection Issues

Check that the database is ready:
```bash
docker-compose logs db
```

### Queue Jobs Not Processing

Check queue worker logs:
```bash
docker-compose logs -f queue
```

Restart queue worker:
```bash
docker-compose restart queue
```

## Additional Configuration

### Enable Xdebug

Add to the `app` service:

```yaml
environment:
  PHP_EXTENSION_XDEBUG: 1
  PHP_INI_XDEBUG__MODE: debug
  PHP_INI_XDEBUG__CLIENT_HOST: host.docker.internal
  PHP_INI_XDEBUG__START_WITH_REQUEST: yes
```

### Add More Cron Jobs

Add to the `scheduler` service:

```yaml
environment:
  CRON_SCHEDULE_2: "0 2 * * *"
  CRON_COMMAND_2: "php /var/www/html/artisan backup:run"
```

### Use PostgreSQL Instead

Replace MySQL with PostgreSQL:

```yaml
  db:
    image: postgres:15
    environment:
      POSTGRES_DB: laravel
      POSTGRES_USER: laravel
      POSTGRES_PASSWORD: secret

  app:
    environment:
      PHP_EXTENSION_PGSQL: 1
      PHP_EXTENSION_PDO_MYSQL: 0
      DB_CONNECTION: pgsql
```

## Files Structure

```
laravel/
├── app/                    # Your Laravel application
│   ├── app/
│   ├── public/
│   ├── composer.json
│   └── ...
├── docker-compose.yml      # Docker Compose configuration
└── README.md              # This file
```

## References

- [Laravel Documentation](https://laravel.com/docs)
- [Docker PHP Images Main README](../../README.md)
- [Troubleshooting Guide](../../TROUBLESHOOTING.md)

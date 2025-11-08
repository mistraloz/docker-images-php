# Quick Start Guide / Guide de Démarrage Rapide

> [English](#english) | [Français](#français)

---

## English

### 5-Minute Quick Start

This guide will help you get started with thecodingmachine PHP Docker images in just a few minutes.

#### 1. Choose Your Image

There are **2 types** and **3 variants** of images:

**Types:**
- **Fat images**: Come pre-loaded with common PHP extensions (Redis, MySQL, etc.), Composer, and Supercronic
- **Slim images**: Minimal base image - install only what you need

**Variants:**
- `cli` - For CLI scripts and cron jobs
- `apache` - For web applications with Apache server
- `fpm` - For web applications with PHP-FPM (use with Nginx)

**Quick Decision Guide:**
- Local development? → Use **fat** variant
- Production deployment? → Use **slim** variant (smaller image)
- Need a web server? → Use **apache** variant
- Using Nginx? → Use **fpm** variant
- CLI scripts only? → Use **cli** variant

#### 2. Basic Examples

##### Simple Web Application (Apache)

```bash
docker run -p 80:80 -v "$PWD":/var/www/html thecodingmachine/php:8.2-v4-apache
```

Visit http://localhost to see your application.

##### Run a PHP Script (CLI)

```bash
docker run --rm -v "$PWD":/usr/src/app -w /usr/src/app thecodingmachine/php:8.2-v4-cli php script.php
```

##### Docker Compose with MySQL

Create a `docker-compose.yml`:

```yaml
version: '3.8'

services:
  app:
    image: thecodingmachine/php:8.2-v4-apache
    ports:
      - "80:80"
    volumes:
      - ./src:/var/www/html
    environment:
      # Enable PostgreSQL extension
      PHP_EXTENSION_PGSQL: 1
      # Configure PHP settings
      PHP_INI_MEMORY_LIMIT: 256M
      PHP_INI_UPLOAD_MAX_FILESIZE: 50M

  db:
    image: mysql:8.0
    environment:
      MYSQL_ROOT_PASSWORD: secret
      MYSQL_DATABASE: myapp
```

Run with: `docker-compose up`

#### 3. Enable PHP Extensions (Fat Image)

```yaml
services:
  app:
    image: thecodingmachine/php:8.2-v4-apache
    environment:
      # Enable extensions
      PHP_EXTENSION_PGSQL: 1
      PHP_EXTENSION_GD: 1
      PHP_EXTENSION_INTL: 1
      # Or use the shorthand
      PHP_EXTENSIONS: pgsql gd intl
```

#### 4. Configure PHP Settings

All `php.ini` settings can be configured via environment variables using the pattern `PHP_INI_<SETTING_NAME>`:

```yaml
environment:
  PHP_INI_MEMORY_LIMIT: 512M
  PHP_INI_MAX_EXECUTION_TIME: 60
  PHP_INI_UPLOAD_MAX_FILESIZE: 100M
  PHP_INI_POST_MAX_SIZE: 100M
  PHP_INI_DISPLAY_ERRORS: 1
```

#### 5. Using NodeJS (for Asset Building)

If you need to build frontend assets (webpack, npm, etc.):

```dockerfile
FROM thecodingmachine/php:8.2-v4-apache-node18

WORKDIR /var/www/html
COPY . .

# Install PHP dependencies
RUN composer install --no-dev --optimize-autoloader

# Install and build frontend assets
RUN npm install
RUN npm run build
```

#### 6. Production-Ready Slim Image

For production, use slim images and install only required extensions:

```dockerfile
# Important: ARG must be before FROM
ARG PHP_EXTENSIONS="mysqli pdo_mysql redis"

FROM thecodingmachine/php:8.2-v4-slim-apache

WORKDIR /var/www/html
COPY . .

RUN composer install --no-dev --optimize-autoloader

# Configure PHP for production
ENV PHP_INI_MEMORY_LIMIT=256M \
    PHP_INI_OPCACHE_ENABLE=1 \
    PHP_INI_DISPLAY_ERRORS=0
```

Build: `docker build -t my-app .`

#### 7. Common Use Cases

##### Laravel Application

```dockerfile
FROM thecodingmachine/php:8.2-v4-apache

ENV APACHE_DOCUMENT_ROOT=/var/www/html/public

WORKDIR /var/www/html
COPY . .

RUN composer install --optimize-autoloader --no-dev
RUN php artisan config:cache
RUN php artisan route:cache
RUN php artisan view:cache
```

##### Symfony Application

```dockerfile
FROM thecodingmachine/php:8.2-v4-apache

ENV APACHE_DOCUMENT_ROOT=/var/www/html/public
ENV PHP_EXTENSION_INTL=1
ENV PHP_EXTENSION_PGSQL=1

WORKDIR /var/www/html
COPY . .

RUN composer install --no-dev --optimize-autoloader
RUN php bin/console cache:clear --env=prod
```

#### 8. Handling File Permissions

These images automatically handle Docker file permission issues:

```yaml
services:
  app:
    image: thecodingmachine/php:8.2-v4-apache
    environment:
      # Run as your local user (Linux/Mac)
      STARTUP_COMMAND_1: "sudo usermod -u $(id -u) docker"
      STARTUP_COMMAND_2: "sudo groupmod -g $(id -g) docker"
```

Or set specific user/group:

```yaml
environment:
  DOCKER_USER_UID: 1000
  DOCKER_USER_GID: 1000
```

#### 9. Enable Xdebug (Development)

```yaml
services:
  app:
    image: thecodingmachine/php:8.2-v4-apache
    environment:
      PHP_EXTENSION_XDEBUG: 1
      PHP_INI_XDEBUG__MODE: debug
      PHP_INI_XDEBUG__CLIENT_HOST: host.docker.internal
      PHP_INI_XDEBUG__START_WITH_REQUEST: yes
```

#### 10. Running Cron Jobs (Fat Image Only)

Fat images include Supercronic for cron jobs:

```yaml
environment:
  # Run a command every minute
  CRON_SCHEDULE_1: "* * * * *"
  CRON_COMMAND_1: "php /var/www/html/artisan schedule:run"

  # Backup database every day at 2am
  CRON_SCHEDULE_2: "0 2 * * *"
  CRON_COMMAND_2: "php /var/www/html/bin/console app:backup"
```

#### Next Steps

- Read the full [README.md](README.md) for all features
- Check [TROUBLESHOOTING.md](TROUBLESHOOTING.md) if you encounter issues
- Learn about the [architecture](ARCHITECTURE.md) to understand how images work
- See more [examples](docs/examples/) for specific use cases

---

## Français

### Démarrage Rapide en 5 Minutes

Ce guide vous aidera à démarrer avec les images Docker PHP de thecodingmachine en quelques minutes.

#### 1. Choisissez Votre Image

Il existe **2 types** et **3 variantes** d'images :

**Types :**
- **Images fat (complètes)** : Pré-chargées avec les extensions PHP courantes (Redis, MySQL, etc.), Composer et Supercronic
- **Images slim (minimales)** : Image de base minimale - installez uniquement ce dont vous avez besoin

**Variantes :**
- `cli` - Pour les scripts CLI et les tâches cron
- `apache` - Pour les applications web avec serveur Apache
- `fpm` - Pour les applications web avec PHP-FPM (à utiliser avec Nginx)

**Guide de Décision Rapide :**
- Développement local ? → Utilisez la variante **fat**
- Déploiement en production ? → Utilisez la variante **slim** (image plus petite)
- Besoin d'un serveur web ? → Utilisez la variante **apache**
- Vous utilisez Nginx ? → Utilisez la variante **fpm**
- Scripts CLI uniquement ? → Utilisez la variante **cli**

#### 2. Exemples de Base

##### Application Web Simple (Apache)

```bash
docker run -p 80:80 -v "$PWD":/var/www/html thecodingmachine/php:8.2-v4-apache
```

Visitez http://localhost pour voir votre application.

##### Exécuter un Script PHP (CLI)

```bash
docker run --rm -v "$PWD":/usr/src/app -w /usr/src/app thecodingmachine/php:8.2-v4-cli php script.php
```

##### Docker Compose avec MySQL

Créez un fichier `docker-compose.yml` :

```yaml
version: '3.8'

services:
  app:
    image: thecodingmachine/php:8.2-v4-apache
    ports:
      - "80:80"
    volumes:
      - ./src:/var/www/html
    environment:
      # Activer l'extension PostgreSQL
      PHP_EXTENSION_PGSQL: 1
      # Configurer les paramètres PHP
      PHP_INI_MEMORY_LIMIT: 256M
      PHP_INI_UPLOAD_MAX_FILESIZE: 50M

  db:
    image: mysql:8.0
    environment:
      MYSQL_ROOT_PASSWORD: secret
      MYSQL_DATABASE: myapp
```

Exécutez avec : `docker-compose up`

#### 3. Activer les Extensions PHP (Image Fat)

```yaml
services:
  app:
    image: thecodingmachine/php:8.2-v4-apache
    environment:
      # Activer les extensions
      PHP_EXTENSION_PGSQL: 1
      PHP_EXTENSION_GD: 1
      PHP_EXTENSION_INTL: 1
      # Ou utilisez la forme courte
      PHP_EXTENSIONS: pgsql gd intl
```

#### 4. Configurer les Paramètres PHP

Tous les paramètres de `php.ini` peuvent être configurés via des variables d'environnement en utilisant le pattern `PHP_INI_<NOM_PARAMETRE>` :

```yaml
environment:
  PHP_INI_MEMORY_LIMIT: 512M
  PHP_INI_MAX_EXECUTION_TIME: 60
  PHP_INI_UPLOAD_MAX_FILESIZE: 100M
  PHP_INI_POST_MAX_SIZE: 100M
  PHP_INI_DISPLAY_ERRORS: 1
```

#### 5. Utiliser NodeJS (pour la Construction d'Assets)

Si vous devez construire des assets frontend (webpack, npm, etc.) :

```dockerfile
FROM thecodingmachine/php:8.2-v4-apache-node18

WORKDIR /var/www/html
COPY . .

# Installer les dépendances PHP
RUN composer install --no-dev --optimize-autoloader

# Installer et construire les assets frontend
RUN npm install
RUN npm run build
```

#### 6. Image Slim Prête pour la Production

Pour la production, utilisez des images slim et installez uniquement les extensions nécessaires :

```dockerfile
# Important : ARG doit être avant FROM
ARG PHP_EXTENSIONS="mysqli pdo_mysql redis"

FROM thecodingmachine/php:8.2-v4-slim-apache

WORKDIR /var/www/html
COPY . .

RUN composer install --no-dev --optimize-autoloader

# Configurer PHP pour la production
ENV PHP_INI_MEMORY_LIMIT=256M \
    PHP_INI_OPCACHE_ENABLE=1 \
    PHP_INI_DISPLAY_ERRORS=0
```

Build : `docker build -t my-app .`

#### 7. Cas d'Usage Courants

##### Application Laravel

```dockerfile
FROM thecodingmachine/php:8.2-v4-apache

ENV APACHE_DOCUMENT_ROOT=/var/www/html/public

WORKDIR /var/www/html
COPY . .

RUN composer install --optimize-autoloader --no-dev
RUN php artisan config:cache
RUN php artisan route:cache
RUN php artisan view:cache
```

##### Application Symfony

```dockerfile
FROM thecodingmachine/php:8.2-v4-apache

ENV APACHE_DOCUMENT_ROOT=/var/www/html/public
ENV PHP_EXTENSION_INTL=1
ENV PHP_EXTENSION_PGSQL=1

WORKDIR /var/www/html
COPY . .

RUN composer install --no-dev --optimize-autoloader
RUN php bin/console cache:clear --env=prod
```

#### 8. Gestion des Permissions de Fichiers

Ces images gèrent automatiquement les problèmes de permissions de fichiers Docker :

```yaml
services:
  app:
    image: thecodingmachine/php:8.2-v4-apache
    environment:
      # Exécuter en tant qu'utilisateur local (Linux/Mac)
      STARTUP_COMMAND_1: "sudo usermod -u $(id -u) docker"
      STARTUP_COMMAND_2: "sudo groupmod -g $(id -g) docker"
```

Ou définir un utilisateur/groupe spécifique :

```yaml
environment:
  DOCKER_USER_UID: 1000
  DOCKER_USER_GID: 1000
```

#### 9. Activer Xdebug (Développement)

```yaml
services:
  app:
    image: thecodingmachine/php:8.2-v4-apache
    environment:
      PHP_EXTENSION_XDEBUG: 1
      PHP_INI_XDEBUG__MODE: debug
      PHP_INI_XDEBUG__CLIENT_HOST: host.docker.internal
      PHP_INI_XDEBUG__START_WITH_REQUEST: yes
```

#### 10. Exécuter des Tâches Cron (Image Fat Uniquement)

Les images fat incluent Supercronic pour les tâches cron :

```yaml
environment:
  # Exécuter une commande chaque minute
  CRON_SCHEDULE_1: "* * * * *"
  CRON_COMMAND_1: "php /var/www/html/artisan schedule:run"

  # Sauvegarder la base de données tous les jours à 2h du matin
  CRON_SCHEDULE_2: "0 2 * * *"
  CRON_COMMAND_2: "php /var/www/html/bin/console app:backup"
```

#### Prochaines Étapes

- Lisez le [README.md](README.md) complet pour toutes les fonctionnalités
- Consultez [TROUBLESHOOTING.md](TROUBLESHOOTING.md) si vous rencontrez des problèmes
- Découvrez l'[architecture](ARCHITECTURE.md) pour comprendre comment fonctionnent les images
- Voir plus d'[exemples](docs/examples/) pour des cas d'usage spécifiques

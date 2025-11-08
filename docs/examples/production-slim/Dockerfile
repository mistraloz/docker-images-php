# Production-ready Dockerfile using slim image
# This example shows how to build a minimal, optimized production image

# IMPORTANT: ARG must be before FROM
ARG PHP_EXTENSIONS="mysqli pdo_mysql redis opcache gd intl"

FROM thecodingmachine/php:8.2-v4-slim-apache

# Install Composer (slim images don't include it)
COPY --from=composer:2 /usr/bin/composer /usr/bin/composer

# Set working directory
WORKDIR /var/www/html

# Copy composer files first (for better layer caching)
COPY composer.json composer.lock ./

# Install PHP dependencies (no dev dependencies)
RUN composer install \
    --no-dev \
    --no-scripts \
    --no-interaction \
    --prefer-dist \
    --optimize-autoloader

# Copy application code
COPY . .

# Run post-install scripts if needed
RUN composer run-script post-install-cmd --no-dev

# Production PHP configuration
ENV PHP_INI_MEMORY_LIMIT=256M \
    PHP_INI_OPCACHE__ENABLE=1 \
    PHP_INI_OPCACHE__MEMORY_CONSUMPTION=256 \
    PHP_INI_OPCACHE__INTERNED_STRINGS_BUFFER=16 \
    PHP_INI_OPCACHE__MAX_ACCELERATED_FILES=20000 \
    PHP_INI_OPCACHE__VALIDATE_TIMESTAMPS=0 \
    PHP_INI_OPCACHE__SAVE_COMMENTS=0 \
    PHP_INI_DISPLAY_ERRORS=0 \
    PHP_INI_ERROR_REPORTING=E_ALL \
    PHP_INI_LOG_ERRORS=1 \
    PHP_INI_EXPOSE_PHP=0

# Apache configuration
ENV APACHE_DOCUMENT_ROOT=/var/www/html/public

# Set proper permissions
RUN chown -R docker:docker /var/www/html

# Health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=40s --retries=3 \
    CMD curl -f http://localhost/ || exit 1

# The image already has ENTRYPOINT and CMD configured

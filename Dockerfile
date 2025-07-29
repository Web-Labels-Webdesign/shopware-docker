# Build arguments for Shopware version selection
ARG SHOPWARE_VERSION=6.6.10.6
ARG SHOPWARE_REPO=https://github.com/shopware/shopware.git
ARG PHP_VERSION=8.2

# Determine PHP version based on Shopware version
FROM docker.io/php:${PHP_VERSION}-fpm

# Re-declare build arguments for use in this stage
ARG SHOPWARE_VERSION=6.6.10.6
ARG SHOPWARE_REPO=https://github.com/shopware/shopware.git

# Install system dependencies
RUN apt-get update && apt-get install -y \
    git \
    curl \
    libpng-dev \
    libonig-dev \
    libxml2-dev \
    libzip-dev \
    libicu-dev \
    libfreetype6-dev \
    libjpeg62-turbo-dev \
    libwebp-dev \
    unzip \
    nodejs \
    npm \
    supervisor \
    nginx \
    && docker-php-ext-configure gd --with-freetype --with-jpeg --with-webp \
    && docker-php-ext-install pdo_mysql mbstring exif pcntl bcmath gd zip intl opcache \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Install Composer
COPY --from=docker.io/composer:latest /usr/bin/composer /usr/bin/composer

# Clone Shopware base repository and checkout specified version
RUN git clone ${SHOPWARE_REPO} /tmp/shopware \
    && cd /tmp/shopware \
    && git checkout v${SHOPWARE_VERSION} \
    && rm -rf .git

# Set working directory and move Shopware files
WORKDIR /var/www/html
RUN mv /tmp/shopware/* /tmp/shopware/.[^.]* /var/www/html/ 2>/dev/null || true \
    && rm -rf /tmp/shopware

# Install Composer dependencies
RUN composer install --no-dev --optimize-autoloader --no-interaction

# Install Node.js dependencies and build assets
RUN npm ci --only=production \
    && npm run build:js \
    && npm run build:css \
    && rm -rf node_modules

# Set environment variables for Shopware
ENV SHOPWARE_VERSION=${SHOPWARE_VERSION}

# Copy PHP configuration
COPY docker/php/php.ini /usr/local/etc/php/conf.d/shopware.ini
COPY docker/php/php-fpm.conf /usr/local/etc/php-fpm.d/www.conf

# Copy Nginx configuration
COPY docker/nginx/default.conf /etc/nginx/sites-available/default

# Copy supervisor configuration
COPY docker/supervisor/supervisord.conf /etc/supervisor/conf.d/supervisord.conf

# Create necessary directories and set permissions
RUN mkdir -p /var/www/html/var/log \
    && mkdir -p /var/www/html/var/cache \
    && mkdir -p /var/www/html/files \
    && mkdir -p /var/www/html/var/plugins \
    && mkdir -p /run/php \
    && mkdir -p /var/lib/php/sessions \
    && chown -R www-data:www-data /var/www/html \
    && chown -R www-data:www-data /var/lib/php/sessions \
    && chmod -R 755 /var/www/html \
    && chmod -R 777 /var/www/html/var \
    && chmod -R 777 /var/www/html/files

# Expose port
EXPOSE 80

# Start supervisor
CMD ["/usr/bin/supervisord", "-c", "/etc/supervisor/conf.d/supervisord.conf"]
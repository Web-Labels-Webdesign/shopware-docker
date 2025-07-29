ARG SHOPWARE_VERSION=6.7
ARG PHP_VERSION=8.3

FROM php:${PHP_VERSION}-apache

# Set build arguments
ARG SHOPWARE_VERSION
ARG SHOPWARE_COMMIT

# Set environment variables
ENV SHOPWARE_VERSION=${SHOPWARE_VERSION}
ENV DEBIAN_FRONTEND=noninteractive
ENV COMPOSER_ALLOW_SUPERUSER=1
ENV COMPOSER_HOME=/tmp/composer

# Install system dependencies
RUN apt-get update && apt-get install -y \
    apt-transport-https \
    ca-certificates \
    curl \
    gnupg \
    lsb-release \
    software-properties-common \
    wget \
    unzip \
    git \
    mariadb-server \
    mariadb-client \
    redis-server \
    nodejs \
    npm \
    supervisor \
    vim \
    nano \
    htop \
    iputils-ping \
    net-tools \
    libzip-dev \
    libicu-dev \
    libonig-dev \
    libxml2-dev \
    libfreetype6-dev \
    libjpeg62-turbo-dev \
    libpng-dev \
    libwebp-dev \
    libxpm-dev \
    && rm -rf /var/lib/apt/lists/*

# Install PHP extensions
RUN docker-php-ext-configure gd --with-freetype --with-jpeg --with-webp \
    && docker-php-ext-install -j$(nproc) \
    gd \
    intl \
    zip \
    pdo \
    pdo_mysql \
    mysqli \
    mbstring \
    xml \
    opcache \
    bcmath \
    soap \
    sockets

# Install Xdebug
RUN pecl install xdebug \
    && docker-php-ext-enable xdebug

# Install Redis PHP extension
RUN pecl install redis \
    && docker-php-ext-enable redis

# Install Composer
COPY --from=composer:latest /usr/bin/composer /usr/bin/composer

# Install Node.js 18 (latest LTS)
RUN curl -fsSL https://deb.nodesource.com/setup_18.x | bash - \
    && apt-get install -y nodejs

# Install Shopware CLI
RUN curl -1sLf 'https://dl.cloudsmith.io/public/friendsofshopware/stable/setup.deb.sh' | bash \
    && apt-get update \
    && apt-get install -y shopware-cli

# Configure Apache
RUN a2enmod rewrite headers env dir mime ssl
COPY docker/apache/shopware.conf /etc/apache2/sites-available/000-default.conf

# Configure PHP
COPY docker/php/php.ini /usr/local/etc/php/conf.d/shopware.ini
COPY docker/php/xdebug.ini /usr/local/etc/php/conf.d/xdebug.ini

# Configure MySQL
COPY docker/mysql/my.cnf /etc/mysql/conf.d/shopware.cnf

# Configure Redis
COPY docker/redis/redis.conf /etc/redis/redis.conf

# Configure Supervisor
COPY docker/supervisor/supervisord.conf /etc/supervisor/conf.d/supervisord.conf

# Create necessary directories
RUN mkdir -p /var/www/html \
    && mkdir -p /var/log/supervisor \
    && mkdir -p /var/run/mysqld \
    && chown mysql:mysql /var/run/mysqld

# Set working directory
WORKDIR /var/www/html

# Clone Shopware from GitHub
RUN git clone https://github.com/shopware/shopware.git . \
    && if [ -n "$SHOPWARE_COMMIT" ]; then git checkout $SHOPWARE_COMMIT; else git checkout $(git describe --tags --abbrev=0 | grep "^v${SHOPWARE_VERSION}"); fi

# Install Shopware dependencies
RUN composer install --no-dev --optimize-autoloader \
    && npm ci --production

# Build Shopware administration and storefront
RUN npm run build:js \
    && npm run build:css

# Set permissions
RUN chown -R www-data:www-data /var/www/html \
    && chmod -R 755 /var/www/html

# Create entrypoint script
COPY docker/entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

# Expose ports
EXPOSE 80 3306 6379

# Health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=60s --retries=3 \
    CMD curl -f http://localhost/ || exit 1

# Start services via supervisor
CMD ["/entrypoint.sh"]

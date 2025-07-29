# Shopware Development Environment
# Complete development setup with Apache, MySQL, Xdebug, and all tools

# Build arguments
ARG SHOPWARE_VERSION
ARG PHP_VERSION

#
# Base stage - Common dependencies
#
FROM ubuntu:22.04 AS base

# Build arguments in stage
ARG SHOPWARE_VERSION
ARG PHP_VERSION

# Metadata
LABEL org.opencontainers.image.title="Shopware ${SHOPWARE_VERSION} Development"
LABEL org.opencontainers.image.description="Shopware ${SHOPWARE_VERSION} development environment with PHP ${PHP_VERSION}"
LABEL org.opencontainers.image.vendor="weblabels"
LABEL org.opencontainers.image.source="https://github.com/weblabels/shopware-docker"
LABEL org.opencontainers.image.licenses="MIT"
LABEL shopware.version="${SHOPWARE_VERSION}"
LABEL php.version="${PHP_VERSION}"

# Environment setup
ENV DEBIAN_FRONTEND=noninteractive
ENV TZ=Europe/Berlin
ENV SHOPWARE_VERSION=${SHOPWARE_VERSION}
ENV PHP_VERSION=${PHP_VERSION}

# Create non-root user early
RUN groupadd --gid 1000 shopware \
    && useradd --uid 1000 --gid shopware --shell /bin/bash --create-home shopware

# Install system dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    # Essential system tools
    ca-certificates \
    curl \
    wget \
    unzip \
    xz-utils \
    git \
    gnupg2 \
    software-properties-common \
    # Clean up
    && rm -rf /var/lib/apt/lists/* \
    && apt-get clean

# Add PHP repository
RUN add-apt-repository ppa:ondrej/php -y && apt-get update

#
# PHP stage - PHP and extensions
#
FROM base AS php-base

# Install PHP and essential extensions
RUN apt-get update && apt-get install -y --no-install-recommends \
    # PHP core
    php${PHP_VERSION} \
    php${PHP_VERSION}-fpm \
    php${PHP_VERSION}-cli \
    php${PHP_VERSION}-common \
    # Database extensions
    php${PHP_VERSION}-mysql \
    php${PHP_VERSION}-pdo \
    # Essential PHP extensions
    php${PHP_VERSION}-zip \
    php${PHP_VERSION}-gd \
    php${PHP_VERSION}-mbstring \
    php${PHP_VERSION}-curl \
    php${PHP_VERSION}-xml \
    php${PHP_VERSION}-bcmath \
    php${PHP_VERSION}-intl \
    php${PHP_VERSION}-xsl \
    php${PHP_VERSION}-soap \
    php${PHP_VERSION}-opcache \
    php${PHP_VERSION}-readline \
    # Security and performance
    php${PHP_VERSION}-apcu \
    # Development extensions
    php${PHP_VERSION}-dev \
    php${PHP_VERSION}-xdebug \
    # Clean up
    && rm -rf /var/lib/apt/lists/* \
    && apt-get clean

# Configure PHP for development
RUN { \
    echo 'memory_limit = 512M'; \
    echo 'max_execution_time = 300'; \
    echo 'upload_max_filesize = 32M'; \
    echo 'post_max_size = 32M'; \
    echo 'allow_url_fopen = On'; \
    echo 'opcache.enable = 1'; \
    echo 'opcache.memory_consumption = 256'; \
    echo 'opcache.interned_strings_buffer = 16'; \
    echo 'opcache.max_accelerated_files = 20000'; \
    echo 'opcache.validate_timestamps = 1'; \
    echo 'opcache.revalidate_freq = 2'; \
    echo 'apcu.enabled = 1'; \
    echo 'apcu.shm_size = 128M'; \
    } > /etc/php/${PHP_VERSION}/fpm/conf.d/99-shopware.ini \
    && cp /etc/php/${PHP_VERSION}/fpm/conf.d/99-shopware.ini /etc/php/${PHP_VERSION}/cli/conf.d/99-shopware.ini \
    # CLI specific settings
    && echo 'memory_limit = 1G' >> /etc/php/${PHP_VERSION}/cli/conf.d/99-shopware.ini \
    && echo 'max_execution_time = 0' >> /etc/php/${PHP_VERSION}/cli/conf.d/99-shopware.ini

# Configure Xdebug for development
RUN { \
    echo "xdebug.mode = debug,coverage,develop"; \
    echo "xdebug.start_with_request = trigger"; \
    echo "xdebug.client_host = host.docker.internal"; \
    echo "xdebug.client_port = 9003"; \
    echo "xdebug.log = /tmp/xdebug.log"; \
    echo "xdebug.log_level = 0"; \
    } >> /etc/php/${PHP_VERSION}/mods-available/xdebug.ini

#
# Node.js stage
#
FROM php-base AS node-base

# Install Node.js with architecture detection
RUN ARCH=$(dpkg --print-architecture) \
    && case "$ARCH" in \
    amd64) NODE_ARCH="x64" ;; \
    arm64) NODE_ARCH="arm64" ;; \
    *) NODE_ARCH="x64" ;; \
    esac \
    && NODE_VERSION=$([ "${SHOPWARE_VERSION%.*}" = "6.7" ] && echo "22.11.0" || echo "20.18.0") \
    && curl -fsSL "https://nodejs.org/dist/v${NODE_VERSION}/node-v${NODE_VERSION}-linux-${NODE_ARCH}.tar.xz" -o node.tar.xz \
    && tar -xJf node.tar.xz -C /usr/local --strip-components=1 \
    && rm node.tar.xz \
    && npm install -g npm@latest \
    # Verify installation
    && node --version \
    && npm --version

#
# Development tools stage
#
FROM node-base AS dev-tools

# Install Composer with verification
RUN curl -sS https://getcomposer.org/installer | php -- --install-dir=/usr/local/bin --filename=composer \
    && composer --version \
    && composer config --global process-timeout 2000 \
    && composer config --global repos.packagist composer https://packagist.org

# Install Shopware CLI
RUN curl -1sLf 'https://dl.cloudsmith.io/public/friendsofshopware/stable/setup.deb.sh' | bash \
    && apt-get update \
    && apt-get install -y --no-install-recommends shopware-cli \
    && rm -rf /var/lib/apt/lists/* \
    && shopware-cli --version

#
# Web server stage
#
FROM dev-tools AS web-server

# Install web server and database
RUN apt-get update && apt-get install -y --no-install-recommends \
    # Web server
    apache2 \
    # Database
    mysql-server \
    mysql-client \
    # Process management
    supervisor \
    # Development tools
    vim \
    nano \
    htop \
    && rm -rf /var/lib/apt/lists/* \
    && apt-get clean

# Fix MySQL user home directory and ensure proper directories
RUN mkdir -p /var/lib/mysql-home /var/lib/mysql /var/run/mysqld /var/log/mysql \
    && chown mysql:mysql /var/lib/mysql-home /var/lib/mysql /var/run/mysqld /var/log/mysql \
    && usermod -d /var/lib/mysql-home mysql \
    && chmod 755 /var/lib/mysql-home \
    # Remove any existing MySQL data to ensure clean initialization at runtime
    && rm -rf /var/lib/mysql/* \
    # Disable MySQL SSL by default for development (keys will be generated at runtime if needed)
    && echo "[mysqld]" >> /etc/mysql/mysql.conf.d/disable-ssl.cnf \
    && echo "skip-ssl" >> /etc/mysql/mysql.conf.d/disable-ssl.cnf \
    && echo "ssl=OFF" >> /etc/mysql/mysql.conf.d/disable-ssl.cnf

# Configure Apache
RUN a2enmod rewrite headers ssl

# Configure MySQL
RUN { \
    echo "[mysqld]"; \
    echo "sql_mode = 'STRICT_TRANS_TABLES,ERROR_FOR_DIVISION_BY_ZERO,NO_AUTO_CREATE_USER,NO_ENGINE_SUBSTITUTION'"; \
    echo "max_allowed_packet = 128M"; \
    echo "innodb_buffer_pool_size = 512M"; \
    echo "innodb_log_file_size = 256M"; \
    echo "innodb_flush_log_at_trx_commit = 2"; \
    echo "innodb_flush_method = O_DIRECT"; \
    } > /etc/mysql/mysql.conf.d/shopware.cnf

#
# Application stage
#
FROM web-server AS application

# Create application directory with proper ownership
RUN mkdir -p /var/www/html \
    && chown -R shopware:shopware /var/www/html

# Set working directory
WORKDIR /var/www/html

# Switch to non-root user for Shopware installation
USER shopware

# Create Shopware project using official template
RUN MAJOR_MINOR=$(echo "$SHOPWARE_VERSION" | cut -d. -f1-2) \
    && echo "Creating Shopware project from official template..." \
    && cd /tmp \
    && COMPOSER_MEMORY_LIMIT=-1 composer create-project "shopware/production:~${MAJOR_MINOR}.0" shopware-project \
    --no-interaction \
    --prefer-dist \
    --ignore-platform-reqs \
    && echo "Moving project files to application directory..." \
    && cd /var/www/html \
    && rm -rf ./* ./.* 2>/dev/null || true \
    && mv /tmp/shopware-project/* /tmp/shopware-project/.* /var/www/html/ 2>/dev/null || true \
    && rmdir /tmp/shopware-project \
    && echo "Setting up environment configuration..." \
    && echo "APP_ENV=dev" > .env.local \
    && echo "DATABASE_URL=mysql://shopware:shopware@localhost:3306/shopware" >> .env.local \
    && echo "APP_URL=http://localhost" >> .env.local

# Create required directories and set permissions
RUN mkdir -p var/cache var/log var/sessions \
    && mkdir -p public/media public/thumbnail public/sitemap \
    && mkdir -p files \
    && mkdir -p custom/plugins custom/themes custom/apps

# Generate required secrets for installation
RUN JWT_PASSPHRASE=$(openssl rand -base64 32) \
    && APP_SECRET=$(openssl rand -hex 32) \
    && INSTANCE_ID=$(openssl rand -hex 32) \
    && echo "JWT_PRIVATE_KEY_PASSPHRASE=${JWT_PASSPHRASE}" >> .env.local \
    && echo "APP_SECRET=${APP_SECRET}" >> .env.local \
    && echo "INSTANCE_ID=${INSTANCE_ID}" >> .env.local \
    && echo "MAILER_URL=smtp://localhost:1025" >> .env.local

# Install Shopware during build (requires temporary MySQL)
RUN echo "Installing Shopware during build process..." \
    # Start MySQL temporarily for installation
    && sudo service mysql start \
    && sleep 5 \
    # Wait for MySQL to be ready
    && timeout 30 bash -c 'until mysqladmin ping -h localhost --silent; do sleep 1; done' \
    # Create database and user
    && sudo mysql -u root <<EOF \
    CREATE DATABASE shopware CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci; \
    CREATE USER 'shopware'@'localhost' IDENTIFIED BY 'shopware'; \
    GRANT ALL PRIVILEGES ON shopware.* TO 'shopware'@'localhost'; \
    FLUSH PRIVILEGES; \
    EOF \
    # Install Shopware
    && php bin/console system:install --basic-setup --force \
    # Install demo data
    && php bin/console framework:demodata --products=50 --categories=10 --media=20 \
    # Clear cache
    && php bin/console cache:clear \
    # Create install lock
    && touch install.lock \
    # Stop MySQL
    && sudo service mysql stop \
    # Clean up temporary files but keep database data
    && rm -rf var/cache/dev/* var/log/* \
    && echo "Shopware installation completed during build"

# Switch back to root for system configuration
USER root

# Copy configuration files
COPY --chown=shopware:shopware apache-shopware.conf /etc/apache2/sites-available/000-default.conf
COPY --chown=shopware:shopware supervisord.conf /etc/supervisor/conf.d/supervisord.conf
COPY --chown=shopware:shopware start.sh /usr/local/bin/start.sh

# Set proper permissions
RUN chmod +x /usr/local/bin/start.sh \
    && chown -R shopware:shopware /var/www/html \
    && chmod -R 755 /var/www/html \
    && chmod -R 775 /var/www/html/var \
    && chmod -R 775 /var/www/html/public/media \
    && chmod -R 775 /var/www/html/public/thumbnail \
    && chmod -R 775 /var/www/html/public/sitemap \
    && chmod -R 775 /var/www/html/files \
    && chmod -R 775 /var/www/html/custom

#
# Final stage - Runtime
#
FROM application AS runtime

# Install Mailpit for email testing
RUN ARCH=$(dpkg --print-architecture) \
    && case "$ARCH" in \
    amd64) MAILPIT_ARCH="amd64" ;; \
    arm64) MAILPIT_ARCH="arm64" ;; \
    arm*) MAILPIT_ARCH="arm" ;; \
    i386) MAILPIT_ARCH="386" ;; \
    *) MAILPIT_ARCH="amd64" ;; \
    esac \
    && MAILPIT_VERSION="v1.27.3" \
    && wget -O mailpit.tar.gz "https://github.com/axllent/mailpit/releases/download/${MAILPIT_VERSION}/mailpit-linux-${MAILPIT_ARCH}.tar.gz" \
    && tar -xzf mailpit.tar.gz -C /usr/local/bin/ \
    && rm mailpit.tar.gz \
    && chmod +x /usr/local/bin/mailpit

# Create volumes to ensure data is not stored in container layer
VOLUME ["/var/lib/mysql", "/var/www/html/var"]

# Expose ports
EXPOSE 80 443 3306 8025 9003

# Health check with better error handling
HEALTHCHECK --interval=30s --timeout=10s --start-period=90s --retries=3 \
    CMD curl -f http://localhost/api/_info/version || \
    curl -f http://localhost/health.php || \
    exit 1

# Start services as root (needed for service management)
USER root

# Start services
CMD ["/usr/local/bin/start.sh"]
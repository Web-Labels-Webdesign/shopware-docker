# Shopware 6.6.10.6 Development Environment
FROM ubuntu:22.04

LABEL maintainer="Your Team <dev@yourcompany.com>"
LABEL org.opencontainers.image.description="Shopware 6.6.10.6 development environment with all dev tools"

# Avoid prompts from apt
ENV DEBIAN_FRONTEND=noninteractive
ENV TZ=Europe/Berlin

# Set Shopware version
ENV SHOPWARE_VERSION=6.6.10.6
ENV PHP_VERSION=8.3

# Add PHP repository for latest versions
RUN apt-get update && apt-get install -y software-properties-common gnupg \
	&& add-apt-repository ppa:ondrej/php -y \
	&& apt-get update

# Install system dependencies
RUN apt-get install -y \
	# Basic system tools
	curl \
	wget \
	unzip \
	xz-utils \
	git \
	vim \
	nano \
	htop \
	supervisor \
	cron \
	# PHP and extensions
	php${PHP_VERSION} \
	php${PHP_VERSION}-fpm \
	php${PHP_VERSION}-cli \
	php${PHP_VERSION}-common \
	php${PHP_VERSION}-mysql \
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
	php${PHP_VERSION}-dev \
	# Xdebug for development
	php${PHP_VERSION}-xdebug \
	# Web server
	apache2 \
	# Database server
	mysql-server \
	# Additional tools
	redis-tools \
	default-mysql-client \
	&& rm -rf /var/lib/apt/lists/*

# Install Node.js 20 (required for Shopware 6.6)  
RUN ARCH=$(dpkg --print-architecture) \
	&& if [ "$ARCH" = "amd64" ]; then NODE_ARCH="x64"; elif [ "$ARCH" = "arm64" ]; then NODE_ARCH="arm64"; else NODE_ARCH="x64"; fi \
	&& curl -fsSL https://nodejs.org/dist/v20.18.0/node-v20.18.0-linux-${NODE_ARCH}.tar.xz -o node.tar.xz \
	&& tar -xJf node.tar.xz -C /usr/local --strip-components=1 \
	&& rm node.tar.xz \
	&& npm install -g npm@latest

# Install Composer
RUN curl -sS https://getcomposer.org/installer | php -- --install-dir=/usr/local/bin --filename=composer \
	&& composer --version \
	&& composer config --global process-timeout 2000 \
	&& composer config --global repos.packagist composer https://packagist.org

# Install Shopware CLI
RUN curl -1sLf 'https://dl.cloudsmith.io/public/friendsofshopware/stable/setup.deb.sh' | bash \
	&& apt-get update \
	&& apt-get install -y shopware-cli

# Configure PHP for development
RUN echo "memory_limit = 1G" >> /etc/php/${PHP_VERSION}/fpm/php.ini \
	&& echo "max_execution_time = 300" >> /etc/php/${PHP_VERSION}/fpm/php.ini \
	&& echo "upload_max_filesize = 32M" >> /etc/php/${PHP_VERSION}/fpm/php.ini \
	&& echo "post_max_size = 32M" >> /etc/php/${PHP_VERSION}/fpm/php.ini \
	&& echo "allow_url_fopen = On" >> /etc/php/${PHP_VERSION}/fpm/php.ini \
	&& echo "memory_limit = 1G" >> /etc/php/${PHP_VERSION}/cli/php.ini \
	&& echo "max_execution_time = 0" >> /etc/php/${PHP_VERSION}/cli/php.ini

# Configure Xdebug for development
RUN echo "xdebug.mode = debug,coverage,develop" >> /etc/php/${PHP_VERSION}/mods-available/xdebug.ini \
	&& echo "xdebug.start_with_request = yes" >> /etc/php/${PHP_VERSION}/mods-available/xdebug.ini \
	&& echo "xdebug.client_host = host.docker.internal" >> /etc/php/${PHP_VERSION}/mods-available/xdebug.ini \
	&& echo "xdebug.client_port = 9003" >> /etc/php/${PHP_VERSION}/mods-available/xdebug.ini \
	&& echo "xdebug.log = /tmp/xdebug.log" >> /etc/php/${PHP_VERSION}/mods-available/xdebug.ini

# Configure Apache
RUN a2enmod rewrite \
	&& a2enmod headers \
	&& a2enmod ssl

# Apache virtual host for Shopware
COPY apache-shopware.conf /etc/apache2/sites-available/000-default.conf

# Configure MySQL
RUN echo "sql_mode = 'STRICT_TRANS_TABLES,ERROR_FOR_DIVISION_BY_ZERO,NO_AUTO_CREATE_USER,NO_ENGINE_SUBSTITUTION'" >> /etc/mysql/mysql.conf.d/mysqld.cnf \
	&& echo "max_allowed_packet = 128M" >> /etc/mysql/mysql.conf.d/mysqld.cnf \
	&& echo "innodb_buffer_pool_size = 1G" >> /etc/mysql/mysql.conf.d/mysqld.cnf \
	&& mkdir -p /var/lib/mysql-home \
	&& chown mysql:mysql /var/lib/mysql-home \
	&& usermod -d /var/lib/mysql-home mysql \
	&& mysqld --initialize-insecure --user=mysql --datadir=/var/lib/mysql

# Create web directory
RUN mkdir -p /var/www/html && chown -R www-data:www-data /var/www/html

# Set working directory
WORKDIR /var/www/html

# Create composer.json for better caching
COPY <<EOF composer.json
{
    "require": {
        "shopware/core": "~6.6.0",
        "shopware/administration": "~6.6.0",
        "shopware/storefront": "~6.6.0"
    },
    "config": {
        "allow-plugins": {
            "symfony/flex": true,
            "symfony/runtime": true
        }
    },
    "extra": {
        "symfony": {
            "allow-contrib": true
        }
    }
}
EOF

# Install dependencies (cached layer)
RUN COMPOSER_MEMORY_LIMIT=-1 composer install --no-dev --optimize-autoloader --ignore-platform-reqs

# Create Shopware project structure
RUN echo "Cleaning working directory..." \
    && rm -rf ./* .[!.]* 2>/dev/null || true \
    && echo "Creating Symfony Flex project..." \
    && COMPOSER_MEMORY_LIMIT=-1 composer create-project symfony/skeleton . --no-interaction --prefer-dist --ignore-platform-reqs \
    && echo "Configuring Symfony Flex for contrib recipes..." \
    && composer config extra.symfony.allow-contrib true \
    && echo "Installing Shopware via Symfony Flex..." \
    && COMPOSER_MEMORY_LIMIT=-1 composer require shopware/core:~6.6.0 shopware/administration:~6.6.0 shopware/storefront:~6.6.0 --no-interaction --ignore-platform-reqs \
    && echo "Setting up Shopware environment..." \
    && echo "APP_ENV=dev" > .env.local \
    && echo "DATABASE_URL=mysql://shopware:shopware@localhost:3306/shopware" >> .env.local \
    && echo "APP_URL=http://localhost" >> .env.local

# Skip dev dependencies in Docker build for faster builds
# They can be installed at runtime if needed

# Skip npm dependencies in Docker build for faster builds
# Create minimal package.json for runtime
RUN echo '{"scripts": {"build": "echo Build complete"}}' > package.json

# Create required directories and set proper permissions
RUN mkdir -p var/cache var/log var/sessions \
	&& mkdir -p public/media public/thumbnail public/sitemap \
	&& mkdir -p files \
	&& chown -R www-data:www-data /var/www/html \
	&& chmod -R 755 /var/www/html \
	&& chmod -R 777 var \
	&& chmod -R 777 public/media public/thumbnail public/sitemap \
	&& chmod -R 777 files

# Copy configuration files
COPY .env.dev /var/www/html/.env
COPY supervisord.conf /etc/supervisor/conf.d/supervisord.conf
COPY start.sh /usr/local/bin/start.sh

# Make start script executable
RUN chmod +x /usr/local/bin/start.sh

# Install MailHog for email testing
RUN wget -O /usr/local/bin/mailhog https://github.com/mailhog/MailHog/releases/download/v1.0.1/MailHog_linux_amd64 \
	&& chmod +x /usr/local/bin/mailhog

# Expose ports
EXPOSE 80 443 3306 8025 9003

# Health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=60s \
	CMD curl -f http://localhost/api/_info/version || exit 1

# Start services
CMD ["/usr/local/bin/start.sh"]
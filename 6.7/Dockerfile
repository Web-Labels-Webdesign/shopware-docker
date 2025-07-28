# Shopware 6.7.1.0 Development Environment
FROM ubuntu:22.04

LABEL maintainer="Your Team <dev@yourcompany.com>"
LABEL org.opencontainers.image.description="Shopware 6.7.1.0 development environment with all dev tools"

# Avoid prompts from apt
ENV DEBIAN_FRONTEND=noninteractive
ENV TZ=Europe/Berlin

# Set Shopware version
ENV SHOPWARE_VERSION=6.7.1.0
ENV PHP_VERSION=8.4

# Install system dependencies
RUN apt-get update && apt-get install -y \
	# Basic system tools
	curl \
	wget \
	unzip \
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
	php${PHP_VERSION}-json \
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
	# Node.js (required for admin/storefront building)
	nodejs \
	npm \
	# Additional tools
	redis-tools \
	default-mysql-client \
	&& rm -rf /var/lib/apt/lists/*

# Install Node.js 22 (required for Shopware 6.7)
RUN curl -fsSL https://deb.nodesource.com/setup_22.x | bash - \
	&& apt-get install -y nodejs \
	&& npm install -g npm@latest

# Install Composer
RUN curl -sS https://getcomposer.org/installer | php -- --install-dir=/usr/local/bin --filename=composer

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
	&& echo "innodb_buffer_pool_size = 1G" >> /etc/mysql/mysql.conf.d/mysqld.cnf

# Create web directory
RUN mkdir -p /var/www/html && chown -R www-data:www-data /var/www/html

# Set working directory
WORKDIR /var/www/html

# Create Shopware project using production template with dev setup
RUN composer create-project shopware/production:${SHOPWARE_VERSION} . --no-interaction --prefer-dist

# Install development dependencies
RUN composer require --dev \
	shopware/dev-tools \
	symfony/profiler-pack \
	symfony/debug-bundle \
	symfony/var-dumper

# Clone Shopware platform repository for development scripts
RUN git clone --depth 1 --branch v${SHOPWARE_VERSION} https://github.com/shopware/shopware.git /tmp/shopware-repo \
	&& cp /tmp/shopware-repo/package.json /var/www/html/ \
	&& rm -rf /tmp/shopware-repo

# Install npm dependencies for development scripts
RUN npm install --include=dev

# Add Shopware development scripts to package.json
RUN npm pkg set scripts.admin:code-mods="@npm:admin run code-mods --" \
	&& npm pkg set scripts.admin:build="@npm:admin run build" \
	&& npm pkg set scripts.admin:dev="@npm:admin run dev" \
	&& npm pkg set scripts.admin:watch="@npm:admin run watch" \
	&& npm pkg set scripts.storefront:build="@npm:storefront run build" \
	&& npm pkg set scripts.storefront:dev="@npm:storefront run dev" \
	&& npm pkg set scripts.storefront:watch="@npm:storefront run watch" \
	&& npm pkg set scripts.build:admin="bin/console bundle:dump && npm run admin:build" \
	&& npm pkg set scripts.build:storefront="npm run storefront:build" \
	&& npm pkg set scripts.build:all="npm run build:admin && npm run build:storefront" \
	&& npm pkg set scripts.watch:admin="npm run admin:watch" \
	&& npm pkg set scripts.watch:storefront="npm run storefront:watch"

# Set proper permissions
RUN chown -R www-data:www-data /var/www/html \
	&& chmod -R 755 /var/www/html \
	&& chmod -R 777 /var/www/html/var \
	&& chmod -R 777 /var/www/html/public/media \
	&& chmod -R 777 /var/www/html/public/thumbnail \
	&& chmod -R 777 /var/www/html/public/sitemap \
	&& chmod -R 777 /var/www/html/files

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
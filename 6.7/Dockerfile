# Shopware 6.7 Development Environment
FROM ubuntu:22.04

LABEL maintainer="Development Team"
LABEL description="Shopware 6.7 development environment with all dev tools"

# Avoid prompts from apt
ENV DEBIAN_FRONTEND=noninteractive
ENV TZ=Europe/Berlin

# Set Shopware and PHP versions
ENV SHOPWARE_VERSION=6.7.1.0
ENV PHP_VERSION=8.4

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

# Install Node.js 22 (required for Shopware 6.7 development)
RUN curl -fsSL https://nodejs.org/dist/v22.11.0/node-v22.11.0-linux-x64.tar.xz -o node.tar.xz \
	&& tar -xJf node.tar.xz -C /usr/local --strip-components=1 \
	&& rm node.tar.xz \
	&& npm install -g npm@latest

# Install Composer
RUN curl -sS https://getcomposer.org/installer | php -- --install-dir=/usr/local/bin --filename=composer \
	&& composer --version \
	&& composer config --global process-timeout 2000

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

# Configure MySQL
RUN echo "sql_mode = 'STRICT_TRANS_TABLES,ERROR_FOR_DIVISION_BY_ZERO,NO_AUTO_CREATE_USER,NO_ENGINE_SUBSTITUTION'" >> /etc/mysql/mysql.conf.d/mysqld.cnf \
	&& echo "max_allowed_packet = 128M" >> /etc/mysql/mysql.conf.d/mysqld.cnf \
	&& echo "innodb_buffer_pool_size = 1G" >> /etc/mysql/mysql.conf.d/mysqld.cnf

# Create web directory
RUN mkdir -p /var/www/html && chown -R www-data:www-data /var/www/html

# Set working directory
WORKDIR /var/www/html

# Clone Shopware development repository
RUN echo "Cloning Shopware development repository..." \
	&& git clone --depth 1 --branch v${SHOPWARE_VERSION} https://github.com/shopware/shopware.git . 2>/dev/null || \
	   git clone --depth 1 --branch 6.7.1.0 https://github.com/shopware/shopware.git . 2>/dev/null || \
	   git clone --depth 1 https://github.com/shopware/shopware.git . \
	&& echo "Shopware development repository cloned successfully"

# Install PHP dependencies (development mode)
RUN echo "Installing PHP dependencies for development..." \
	&& COMPOSER_MEMORY_LIMIT=-1 composer install --no-interaction --ignore-platform-reqs \
	&& echo "PHP dependencies installed"

# Install Node.js dependencies for development
RUN echo "Installing Node.js dependencies..." \
	&& npm ci \
	&& echo "Node.js dependencies installed"

# Build development assets
RUN echo "Building development assets..." \
	&& npm run build-js \
	&& echo "Development assets built"

# Create required directories and set permissions
RUN mkdir -p var/cache var/log var/sessions \
	&& mkdir -p public/media public/thumbnail public/sitemap \
	&& mkdir -p files \
	&& mkdir -p custom/plugins custom/themes custom/apps \
	&& chown -R www-data:www-data /var/www/html \
	&& chmod -R 755 /var/www/html \
	&& chmod -R 777 var \
	&& chmod -R 777 public/media public/thumbnail public/sitemap \
	&& chmod -R 777 files \
	&& chmod -R 777 custom

# Copy configuration files
COPY apache-shopware.conf /etc/apache2/sites-available/000-default.conf
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
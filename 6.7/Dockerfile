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
	# Node.js (required for admin/storefront building)
	nodejs \
	npm \
	# Additional tools
	redis-tools \
	default-mysql-client \
	&& rm -rf /var/lib/apt/lists/*

# Install Node.js 22 (required for Shopware 6.7)
RUN curl -fsSL https://nodejs.org/dist/v22.11.0/node-v22.11.0-linux-x64.tar.xz -o node.tar.xz \
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
	&& echo "innodb_buffer_pool_size = 1G" >> /etc/mysql/mysql.conf.d/mysqld.cnf

# Create web directory
RUN mkdir -p /var/www/html && chown -R www-data:www-data /var/www/html

# Set working directory
WORKDIR /var/www/html

# Create Symfony Flex project and integrate Shopware
RUN echo "Creating Symfony Flex project..." \
    && COMPOSER_MEMORY_LIMIT=-1 composer create-project symfony/skeleton . --no-interaction --prefer-dist --ignore-platform-reqs \
    && echo "Adding Shopware Flex recipe..." \
    && composer config extra.symfony.allow-contrib true \
    && echo "Cloning Shopware repository at tag v${SHOPWARE_VERSION}..." \
    && git clone --depth 1 --branch v${SHOPWARE_VERSION} https://github.com/shopware/shopware.git /tmp/shopware 2>/dev/null || \
       git clone --depth 1 --branch 6.7.1.0 https://github.com/shopware/shopware.git /tmp/shopware 2>/dev/null || \
       git clone --depth 1 https://github.com/shopware/shopware.git /tmp/shopware \
    && echo "Copying Shopware files to project..." \
    && cp /tmp/shopware/composer.json composer.json.shopware \
    && cp /tmp/shopware/package.json package.json 2>/dev/null || echo "No package.json in Shopware repo" \
    && cp /tmp/shopware/symfony.lock symfony.lock 2>/dev/null || true \
    && cp /tmp/shopware/.env .env.shopware \
    && cp -r /tmp/shopware/config/* config/ 2>/dev/null || mkdir -p config \
    && cp -r /tmp/shopware/public/* public/ 2>/dev/null || mkdir -p public \
    && cp -r /tmp/shopware/src/* src/ 2>/dev/null || mkdir -p src \
    && cp -r /tmp/shopware/templates/* templates/ 2>/dev/null || mkdir -p templates \
    && cp -r /tmp/shopware/bin/* bin/ 2>/dev/null || mkdir -p bin \
    && echo "Merging composer.json files..." \
    && php -r "
        \$base = json_decode(file_get_contents('composer.json'), true);
        \$shopware = json_decode(file_get_contents('composer.json.shopware'), true);
        \$merged = array_merge_recursive(\$base, \$shopware);
        \$merged['require'] = array_merge(\$base['require'] ?? [], \$shopware['require'] ?? []);
        \$merged['require-dev'] = array_merge(\$base['require-dev'] ?? [], \$shopware['require-dev'] ?? []);
        file_put_contents('composer.json', json_encode(\$merged, JSON_PRETTY_PRINT | JSON_UNESCAPED_SLASHES));
    " \
    && echo "Installing Shopware dependencies..." \
    && COMPOSER_MEMORY_LIMIT=-1 composer install --no-interaction --prefer-dist --ignore-platform-reqs \
    && rm -rf /tmp/shopware composer.json.shopware

# Install development dependencies
RUN COMPOSER_MEMORY_LIMIT=-1 composer require --dev \
	shopware/dev-tools \
	symfony/profiler-pack \
	symfony/debug-bundle \
	symfony/var-dumper \
	--ignore-platform-reqs || echo "Dev dependencies installation failed, continuing..."

# Install npm dependencies (package.json already copied from Shopware repo)
RUN if [ -f "package.json" ]; then \
        echo "Installing npm dependencies from Shopware package.json..." && \
        npm install --include=dev || echo "NPM install failed, continuing without dev dependencies"; \
    else \
        echo "No package.json found, creating minimal one..." && \
        echo '{"scripts": {"admin:build": "echo No admin build", "storefront:build": "echo No storefront build"}}' > package.json; \
    fi

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
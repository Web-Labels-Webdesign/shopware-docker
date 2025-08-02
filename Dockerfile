ARG SHOPWARE_VERSION=6.6
ARG NODE_VERSION=""
ARG DB_ENGINE=mariadb

# Dynamic PHP version selection based on Shopware version
FROM php:8.1-fpm-alpine AS php-8.1
FROM php:8.2-fpm-alpine AS php-8.2
FROM php:8.3-fpm-alpine AS php-8.3

# Select appropriate PHP version based on Shopware version
FROM php-8.1 AS shopware-6.5
FROM php-8.2 AS shopware-6.6
FROM php-8.3 AS shopware-6.7

FROM shopware-${SHOPWARE_VERSION} AS base

# Install system dependencies
RUN apk add --no-cache \
    nginx \
    supervisor \
    mysql \
    mysql-client \
    mariadb \
    mariadb-client \
    redis \
    nodejs \
    npm \
    curl \
    wget \
    git \
    unzip \
    libzip-dev \
    libpng-dev \
    libjpeg-turbo-dev \
    freetype-dev \
    icu-dev \
    oniguruma-dev \
    libxml2-dev \
    openssl-dev \
    bash \
    shadow \
    procps \
    && rm -rf /var/cache/apk/*

# Install PHP extensions
RUN docker-php-ext-configure gd --with-freetype --with-jpeg \
    && docker-php-ext-install -j$(nproc) \
        pdo_mysql \
        zip \
        gd \
        intl \
        mbstring \
        xml \
        soap \
        bcmath \
        sockets \
        opcache

# Install Redis PHP extension
RUN pecl install redis && docker-php-ext-enable redis

# Install Xdebug
RUN pecl install xdebug && docker-php-ext-enable xdebug

# Install Composer
COPY --from=composer:2 /usr/bin/composer /usr/bin/composer

# Set up Node.js version based on Shopware version
ARG SHOPWARE_VERSION
ARG NODE_VERSION
RUN if [ "$SHOPWARE_VERSION" = "6.5" ]; then \
        NODE_DEFAULT="18"; \
    else \
        NODE_DEFAULT="20"; \
    fi; \
    NODE_VER=${NODE_VERSION:-$NODE_DEFAULT}; \
    npm install -g n && n $NODE_VER && npm install -g npm@latest

# Install Elasticsearch for 6.7.x
RUN if [ "$SHOPWARE_VERSION" = "6.7" ]; then \
        wget -qO - https://artifacts.elastic.co/GPG-KEY-elasticsearch | gpg --dearmor -o /usr/share/keyrings/elasticsearch-keyring.gpg && \
        echo "deb [signed-by=/usr/share/keyrings/elasticsearch-keyring.gpg] https://artifacts.elastic.co/packages/7.x/apt stable main" > /etc/apt/sources.list.d/elastic-7.x.list && \
        apk add --no-cache openjdk11-jre && \
        mkdir -p /opt/elasticsearch && \
        wget -O - https://artifacts.elastic.co/downloads/elasticsearch/elasticsearch-7.17.15-linux-x86_64.tar.gz | tar -xzC /opt/elasticsearch --strip-components=1; \
    fi

# Create application directory
WORKDIR /var/www/html

# Install Shopware - always get the latest patch version
ARG SHOPWARE_VERSION
RUN COMPOSER_ALLOW_SUPERUSER=1 composer create-project shopware/production:^${SHOPWARE_VERSION}.0 . --no-dev --no-scripts

# Set proper permissions
RUN chown -R www-data:www-data /var/www/html

# Configure PHP
COPY <<EOF /usr/local/etc/php/conf.d/shopware.ini
memory_limit = 512M
upload_max_filesize = 64M
post_max_size = 64M
max_execution_time = 300
opcache.enable = 1
opcache.memory_consumption = 256
opcache.max_accelerated_files = 20000
opcache.validate_timestamps = 0
opcache.save_comments = 1
opcache.fast_shutdown = 1
EOF

# Configure Xdebug
COPY <<EOF /usr/local/etc/php/conf.d/xdebug.ini
xdebug.mode = debug
xdebug.start_with_request = yes
xdebug.client_host = host.docker.internal
xdebug.client_port = 9003
xdebug.log = /tmp/xdebug.log
EOF

# Configure Nginx
COPY <<EOF /etc/nginx/nginx.conf
user www-data;
worker_processes auto;
pid /run/nginx.pid;

events {
    worker_connections 1024;
}

http {
    include /etc/nginx/mime.types;
    default_type application/octet-stream;
    
    sendfile on;
    tcp_nopush on;
    tcp_nodelay on;
    keepalive_timeout 65;
    types_hash_max_size 2048;
    
    server {
        listen 80;
        root /var/www/html/public;
        index index.php;
        
        location / {
            try_files \$uri \$uri/ /index.php\$is_args\$args;
        }
        
        location ~ \.php$ {
            fastcgi_pass 127.0.0.1:9000;
            fastcgi_index index.php;
            fastcgi_param SCRIPT_FILENAME \$document_root\$fastcgi_script_name;
            include fastcgi_params;
        }
        
        location ~* \.(css|js|gif|ico|jpeg|jpg|png|svg|woff|woff2|ttf|eot)$ {
            expires 1y;
            add_header Cache-Control "public, immutable";
            access_log off;
        }
    }
}
EOF

# Configure database based on DB_ENGINE
ARG DB_ENGINE
RUN if [ "$DB_ENGINE" = "mysql" ]; then \
        echo "mysql" > /tmp/db_engine; \
    else \
        echo "mariadb" > /tmp/db_engine; \
    fi

# Install Adminer
RUN mkdir -p /var/www/adminer && \
    wget -O /var/www/adminer/index.php https://www.adminer.org/latest.php

# Configure Adminer Nginx
COPY <<EOF /etc/nginx/sites-available/adminer
server {
    listen 8080;
    root /var/www/adminer;
    index index.php;
    
    location ~ \.php$ {
        fastcgi_pass 127.0.0.1:9000;
        fastcgi_index index.php;
        fastcgi_param SCRIPT_FILENAME \$document_root\$fastcgi_script_name;
        include fastcgi_params;
    }
}
EOF

# Install MailCatcher
RUN apk add --no-cache ruby ruby-dev build-base && \
    gem install mailcatcher && \
    apk del ruby-dev build-base

# Create supervisor configuration
COPY <<EOF /etc/supervisor/conf.d/supervisord.conf
[supervisord]
nodaemon=true
user=root

[program:php-fpm]
command=php-fpm --nodaemonize
autorestart=true
stdout_logfile=/dev/stdout
stdout_logfile_maxbytes=0
stderr_logfile=/dev/stderr
stderr_logfile_maxbytes=0

[program:nginx]
command=nginx -g 'daemon off;'
autorestart=true
stdout_logfile=/dev/stdout
stdout_logfile_maxbytes=0
stderr_logfile=/dev/stderr
stderr_logfile_maxbytes=0

[program:database]
command=sh -c 'if [ "$(cat /tmp/db_engine)" = "mysql" ]; then mysqld --user=root --bind-address=0.0.0.0; else mariadbd --user=root --bind-address=0.0.0.0; fi'
autorestart=true
stdout_logfile=/dev/stdout
stdout_logfile_maxbytes=0
stderr_logfile=/dev/stderr
stderr_logfile_maxbytes=0

[program:redis]
command=redis-server --bind 0.0.0.0
autorestart=true
stdout_logfile=/dev/stdout
stdout_logfile_maxbytes=0
stderr_logfile=/dev/stderr
stderr_logfile_maxbytes=0

[program:mailcatcher]
command=mailcatcher --foreground --ip=0.0.0.0 --smtp-port=1025 --http-port=1080
autorestart=true
stdout_logfile=/dev/stdout
stdout_logfile_maxbytes=0
stderr_logfile=/dev/stderr
stderr_logfile_maxbytes=0
EOF

# Add Elasticsearch to supervisor for 6.7.x
RUN if [ "$SHOPWARE_VERSION" = "6.7" ]; then \
        echo "[program:elasticsearch]" >> /etc/supervisor/conf.d/supervisord.conf && \
        echo "command=/opt/elasticsearch/bin/elasticsearch" >> /etc/supervisor/conf.d/supervisord.conf && \
        echo "user=www-data" >> /etc/supervisor/conf.d/supervisord.conf && \
        echo "environment=ES_JAVA_OPTS=\"-Xms512m -Xmx512m\",discovery.type=single-node" >> /etc/supervisor/conf.d/supervisord.conf && \
        echo "autorestart=true" >> /etc/supervisor/conf.d/supervisord.conf && \
        echo "stdout_logfile=/dev/stdout" >> /etc/supervisor/conf.d/supervisord.conf && \
        echo "stdout_logfile_maxbytes=0" >> /etc/supervisor/conf.d/supervisord.conf && \
        echo "stderr_logfile=/dev/stderr" >> /etc/supervisor/conf.d/supervisord.conf && \
        echo "stderr_logfile_maxbytes=0" >> /etc/supervisor/conf.d/supervisord.conf; \
    fi

# Create initialization script
COPY <<EOF /usr/local/bin/init-shopware.sh
#!/bin/bash
set -e

# Handle UID/GID remapping
if [ ! -z "\$UID" ] && [ ! -z "\$GID" ]; then
    usermod -u \$UID www-data
    groupmod -g \$GID www-data
    chown -R www-data:www-data /var/www/html
fi

# Initialize database
DB_ENGINE=\$(cat /tmp/db_engine)
if [ "\$DB_ENGINE" = "mysql" ]; then
    mysql_install_db --user=root --datadir=/var/lib/mysql
    mysqld --user=root --skip-networking &
    sleep 5
    mysql -u root -e "CREATE DATABASE IF NOT EXISTS shopware;"
    mysql -u root -e "CREATE USER IF NOT EXISTS 'shopware'@'%' IDENTIFIED BY 'shopware';"
    mysql -u root -e "GRANT ALL PRIVILEGES ON shopware.* TO 'shopware'@'%';"
    mysql -u root -e "SET PASSWORD FOR 'root'@'localhost' = PASSWORD('root');"
    mysqladmin -u root -proot shutdown
else
    mysql_install_db --user=root --datadir=/var/lib/mysql
    mariadbd --user=root --skip-networking &
    sleep 5
    mysql -u root -e "CREATE DATABASE IF NOT EXISTS shopware;"
    mysql -u root -e "CREATE USER IF NOT EXISTS 'shopware'@'%' IDENTIFIED BY 'shopware';"
    mysql -u root -e "GRANT ALL PRIVILEGES ON shopware.* TO 'shopware'@'%';"
    mysql -u root -e "SET PASSWORD FOR 'root'@'localhost' = PASSWORD('root');"
    mysqladmin -u root -proot shutdown
fi

# Configure Shopware environment
cat > /var/www/html/.env.local << EOL
APP_ENV=dev
APP_SECRET=shopware-secret
DATABASE_URL=mysql://shopware:shopware@127.0.0.1:3306/shopware
MAILER_URL=smtp://127.0.0.1:1025
SHOPWARE_ES_ENABLED=\$([ "\$SHOPWARE_VERSION" = "6.7" ] && echo "1" || echo "0")
SHOPWARE_ES_HOSTS=127.0.0.1:9200
SHOPWARE_ES_INDEXING_ENABLED=\$([ "\$SHOPWARE_VERSION" = "6.7" ] && echo "1" || echo "0")
SHOPWARE_HTTP_CACHE_ENABLED=0
SHOPWARE_HTTP_DEFAULT_TTL=7200
EOL

# Handle Xdebug configuration
if [ "\${XDEBUG_ENABLED:-1}" = "0" ]; then
    rm -f /usr/local/etc/php/conf.d/docker-php-ext-xdebug.ini
fi

# Install Shopware
cd /var/www/html
composer install --no-dev --optimize-autoloader
bin/console system:install --create-database --basic-setup --admin-username=admin --admin-password=shopware

# Build assets
npm ci
npm run build

# Create asset watchers
cat > /var/www/html/bin/watch-storefront.sh << 'WEOF'
#!/bin/bash
cd /var/www/html
npm run watch-storefront
WEOF

cat > /var/www/html/bin/watch-administration.sh << 'WEOF'
#!/bin/bash
cd /var/www/html
npm run watch-admin
WEOF

chmod +x /var/www/html/bin/watch-*.sh

# Set final permissions
chown -R www-data:www-data /var/www/html
EOF

RUN chmod +x /usr/local/bin/init-shopware.sh

# Create entrypoint script
COPY <<EOF /usr/local/bin/entrypoint.sh
#!/bin/bash
set -e

# Initialize Shopware on first run
if [ ! -f /var/www/html/.env.local ]; then
    /usr/local/bin/init-shopware.sh
fi

# Start supervisor
exec supervisord -c /etc/supervisor/conf.d/supervisord.conf
EOF

RUN chmod +x /usr/local/bin/entrypoint.sh

# Enable Adminer site
RUN ln -sf /etc/nginx/sites-available/adminer /etc/nginx/sites-enabled/

# Expose ports
EXPOSE 80 8080 3306 6379 9200 1025 1080

# Set environment variables
ENV SHOPWARE_VERSION=${SHOPWARE_VERSION}
ENV XDEBUG_ENABLED=1
ENV DB_ENGINE=${DB_ENGINE}

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
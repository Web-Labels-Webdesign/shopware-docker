#!/bin/bash
set -e

echo "Starting Shopware Docker Container..."

# Initialize MySQL if not already initialized
if [ ! -d "/var/lib/mysql/mysql" ]; then
    echo "Initializing MySQL database..."
    mysql_install_db --user=mysql --datadir=/var/lib/mysql
    
    # Start MySQL temporarily to create database and user
    mysqld_safe --user=mysql &
    MYSQL_PID=$!
    
    # Wait for MySQL to start
    until mysqladmin ping >/dev/null 2>&1; do
        echo "Waiting for MySQL to start..."
        sleep 1
    done
    
    # Create database and user
    mysql -e "CREATE DATABASE IF NOT EXISTS shopware;"
    mysql -e "CREATE USER IF NOT EXISTS 'shopware'@'%' IDENTIFIED BY 'shopware';"
    mysql -e "GRANT ALL PRIVILEGES ON shopware.* TO 'shopware'@'%';"
    mysql -e "FLUSH PRIVILEGES;"
    
    # Stop temporary MySQL
    kill $MYSQL_PID
    wait $MYSQL_PID
fi

# Configure Xdebug based on environment variable
if [ "$XDEBUG_ENABLED" = "1" ]; then
    echo "Enabling Xdebug..."
    sed -i 's/xdebug.mode = .*/xdebug.mode = debug,develop,coverage/' /usr/local/etc/php/conf.d/xdebug.ini
    sed -i 's/xdebug.start_with_request = .*/xdebug.start_with_request = yes/' /usr/local/etc/php/conf.d/xdebug.ini
else
    echo "Disabling Xdebug..."
    sed -i 's/xdebug.mode = .*/xdebug.mode = off/' /usr/local/etc/php/conf.d/xdebug.ini
fi

# Install/Update Shopware if .env doesn't exist
if [ ! -f "/var/www/html/.env" ]; then
    echo "Setting up Shopware..."
    
    # Create .env file
    cat > /var/www/html/.env << EOF
APP_ENV=dev
APP_SECRET=defbf9435afe4d3b2c7bb35d66fd10f89ecfd02156cdf829374de69b5f2be83e
INSTANCE_ID=1
DATABASE_URL=mysql://shopware:shopware@localhost:3306/shopware
APP_URL=http://localhost
MAILER_URL=smtp://localhost:1025
COMPOSER_HOME=/tmp/composer
SHOPWARE_HTTP_CACHE_ENABLED=0
SHOPWARE_HTTP_DEFAULT_TTL=7200
SHOPWARE_ES_ENABLED=0
BLUE_GREEN_DEPLOYMENT=0
SHOPWARE_CDN_STRATEGY_DEFAULT=id
LOCK_DSN=flock
EOF

    # Wait for services to be ready
    echo "Starting services..."
    /usr/bin/supervisord -c /etc/supervisor/conf.d/supervisord.conf &
    
    # Wait for MySQL
    until mysqladmin ping >/dev/null 2>&1; do
        echo "Waiting for MySQL to be ready..."
        sleep 2
    done
    
    # Install Shopware
    echo "Installing Shopware..."
    cd /var/www/html
    php bin/console system:install --create-database --basic-setup --force
    
    # Build administration and storefront
    if [ "$SHOPWARE_ADMIN_BUILD_ONLY_EXTENSIONS" != "1" ]; then
        echo "Building Shopware assets..."
        php bin/console bundle:dump
        NODE_OPTIONS="--max-old-space-size=4096" npm run build:js
        php bin/console theme:compile
    fi
    
    # Set correct permissions
    chown -R www-data:www-data /var/www/html
    
    echo "Shopware installation completed!"
else
    echo "Shopware already configured, starting services..."
    /usr/bin/supervisord -c /etc/supervisor/conf.d/supervisord.conf &
    
    # Wait for MySQL
    until mysqladmin ping >/dev/null 2>&1; do
        echo "Waiting for MySQL to be ready..."
        sleep 2
    done
    
    # Run migrations if needed
    cd /var/www/html
    php bin/console database:migrate --all
fi

# Keep container running
wait

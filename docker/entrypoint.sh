#!/bin/bash
set -e

echo "Starting Shopware Docker Container..."

# Ensure MySQL data directory permissions are correct
if [ ! -d "/var/lib/mysql/mysql" ] || [ "$(ls -A /var/lib/mysql)" = "" ]; then
    echo "Initializing MySQL database..."
    mysql_install_db --user=mysql --datadir=/var/lib/mysql
    
    # Start MySQL temporarily to recreate users
    mysqld_safe --user=mysql &
    MYSQL_PID=$!
    
    # Wait for MySQL to start
    until mysqladmin ping >/dev/null 2>&1; do
        echo "Waiting for MySQL to start..."
        sleep 1
    done
    
    # Recreate database and users (in case of fresh container)
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

# Start services
echo "Starting services..."
/usr/bin/supervisord -c /etc/supervisor/conf.d/supervisord.conf &

# Wait for MySQL to be ready
until mysqladmin ping >/dev/null 2>&1; do
    echo "Waiting for MySQL to be ready..."
    sleep 2
done

# Run database migrations if needed
cd /var/www/html
echo "Running database migrations..."
php bin/console database:migrate --all || true

# Rebuild assets only if extensions should be built
if [ "$SHOPWARE_ADMIN_BUILD_ONLY_EXTENSIONS" = "1" ]; then
    echo "Building only extensions..."
    php bin/console bundle:dump
    NODE_OPTIONS="--max-old-space-size=4096" npm run build:js -- --mode=production
fi

# Clear cache
php bin/console cache:clear

echo "Shopware is ready!"
echo "Frontend: http://localhost"
echo "Admin: http://localhost/admin"
echo "Default admin credentials: admin / shopware"

# Keep container running
wait

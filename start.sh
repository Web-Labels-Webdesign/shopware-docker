#!/bin/bash
set -e

echo "🚀 Starting Shopware Development Environment..."

# Create log directories with proper permissions
mkdir -p /var/log/supervisor
chown -R shopware:shopware /var/log/supervisor

# Initialize MySQL if needed
if [ ! -d "/var/lib/mysql/mysql" ]; then
    echo "📦 Initializing MySQL database..."
    mysql_install_db --user=mysql --datadir=/var/lib/mysql
fi

# Start MySQL service
echo "🗄️ Starting MySQL..."
service mysql start

# Wait for MySQL to be ready
echo "⏳ Waiting for MySQL to be ready..."
while ! mysqladmin ping -h localhost --silent; do
    sleep 1
done

# Create Shopware database and user if they don't exist
echo "🔧 Setting up Shopware database..."
mysql -u root -e "CREATE DATABASE IF NOT EXISTS shopware;"
mysql -u root -e "CREATE USER IF NOT EXISTS 'shopware'@'localhost' IDENTIFIED BY 'shopware';"
mysql -u root -e "GRANT ALL PRIVILEGES ON shopware.* TO 'shopware'@'localhost';"
mysql -u root -e "FLUSH PRIVILEGES;"

# Navigate to Shopware directory
cd /var/www/html

# Generate secrets if they don't exist
echo "🔑 Generating application secrets..."
if [ ! -f .env ]; then
    cp .env.local .env
fi

# Generate JWT secret if not exists
if ! grep -q "JWT_PRIVATE_KEY_PASSPHRASE=" .env.local 2>/dev/null; then
    JWT_PASSPHRASE=$(openssl rand -base64 32)
    echo "JWT_PRIVATE_KEY_PASSPHRASE=$JWT_PASSPHRASE" >> .env.local
fi

# Generate APP_SECRET if not exists
if ! grep -q "APP_SECRET=" .env.local 2>/dev/null; then
    APP_SECRET=$(openssl rand -hex 32)
    echo "APP_SECRET=$APP_SECRET" >> .env.local
fi

# Install/Update Shopware if needed
if [ ! -f install.lock ]; then
    echo "🛠️ Installing Shopware..."
    
    # Clear cache first
    su -c "php bin/console cache:clear --env=dev" shopware
    
    # Install Shopware
    su -c "php bin/console system:install --create-database --basic-setup --force" shopware
    
    # Create admin user
    su -c "php bin/console user:create admin --admin --email=\"admin@example.com\" --firstName=\"Shop\" --lastName=\"Admin\" --password=\"shopware\"" shopware
    
    # Generate JWT keypair
    su -c "php bin/console system:generate-jwt-secret --force" shopware
    
    # Install and build assets
    if [ -f package.json ]; then
        echo "📦 Installing and building assets..."
        su -c "npm install --no-audit --no-fund" shopware
        su -c "npm run build:all" shopware
    fi
    
    # Create install lock
    touch install.lock
    chown shopware:shopware install.lock
    
    echo "✅ Shopware installation completed!"
else
    echo "✅ Shopware already installed"
    
    # Update database schema if needed
    su -c "php bin/console database:migrate --all --force" shopware
    
    # Clear cache
    su -c "php bin/console cache:clear --env=dev" shopware
fi

# Set proper permissions
echo "🔐 Setting file permissions..."
chown -R shopware:shopware /var/www/html
chmod -R 755 /var/www/html
chmod -R 775 /var/www/html/var
chmod -R 775 /var/www/html/public/media
chmod -R 775 /var/www/html/public/thumbnail
chmod -R 775 /var/www/html/public/sitemap
chmod -R 775 /var/www/html/files
chmod -R 775 /var/www/html/custom

# Start services via supervisor
echo "🎯 Starting all services..."
exec /usr/bin/supervisord -c /etc/supervisor/conf.d/supervisord.conf
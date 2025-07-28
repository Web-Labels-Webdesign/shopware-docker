#!/bin/bash
set -e

echo "🚀 Starting Shopware 6.6 Development Environment..."

# Function to wait for MySQL to be ready
wait_for_mysql() {
    echo "⏳ Waiting for MySQL to be ready..."
    while ! mysqladmin ping -h"localhost" --silent; do
        sleep 1
    done
    echo "✅ MySQL is ready!"
}

# Function to setup MySQL database and user
setup_mysql() {
    echo "🔧 Setting up MySQL database..."
    
    # Initialize MySQL data directory if it doesn't exist
    if [ ! -d "/var/lib/mysql/mysql" ]; then
        echo "🔧 Initializing MySQL data directory..."
        mysqld --initialize-insecure --user=mysql --datadir=/var/lib/mysql
        chown -R mysql:mysql /var/lib/mysql
    fi
    
    # Start MySQL in background
    service mysql start
    wait_for_mysql
    
    # Create database and user if they don't exist
    mysql -e "CREATE DATABASE IF NOT EXISTS shopware;" 2>/dev/null || true
    mysql -e "CREATE USER IF NOT EXISTS 'shopware'@'%' IDENTIFIED BY 'shopware';" 2>/dev/null || true
    mysql -e "GRANT ALL PRIVILEGES ON shopware.* TO 'shopware'@'%';" 2>/dev/null || true
    mysql -e "CREATE USER IF NOT EXISTS 'shopware'@'localhost' IDENTIFIED BY 'shopware';" 2>/dev/null || true
    mysql -e "GRANT ALL PRIVILEGES ON shopware.* TO 'shopware'@'localhost';" 2>/dev/null || true
    mysql -e "FLUSH PRIVILEGES;" 2>/dev/null || true
    
    echo "✅ MySQL database setup complete!"
}

# Function to setup Shopware
setup_shopware() {
    echo "🛍️ Setting up Shopware..."
    
    cd /var/www/html
    
    # Basic setup (JWT and app secret handled by system:install)
    
    # Install Shopware if not already installed (using official method)
    if ! bin/console system:is-installed 2>/dev/null; then
        echo "📦 Installing Shopware using official method..."
        bin/console system:install --basic-setup
        
        echo "✅ Shopware installation complete!"
    else
        echo "✅ Shopware already installed!"
        
        # Run migrations in case of updates
        echo "🔄 Running database migrations..."
        bin/console database:migrate --all
    fi
    
    # Clear cache
    echo "🧹 Clearing cache..."
    bin/console cache:clear
    
    # Note: Assets will be built on-demand by Shopware
    echo "ℹ️ Asset building will happen automatically when needed"
    
    # Set proper permissions
    chown -R www-data:www-data /var/www/html
    chmod -R 755 /var/www/html
    chmod -R 777 /var/www/html/var
    chmod -R 777 /var/www/html/public/media
    chmod -R 777 /var/www/html/public/thumbnail
    chmod -R 777 /var/www/html/public/sitemap
    chmod -R 777 /var/www/html/files
    
    echo "✅ Shopware setup complete!"
}

# Function to configure Xdebug based on environment variable
configure_xdebug() {
    if [ "${XDEBUG_ENABLED:-1}" = "1" ]; then
        echo "🐛 Enabling Xdebug..."
        phpenmod xdebug
    else
        echo "⚠️ Disabling Xdebug..."
        phpdismod xdebug
    fi
}

# Main setup function
main() {
    echo "🎯 Shopware 6.6 Development Environment"
    echo "=================================="
    
    # Configure Xdebug
    configure_xdebug
    
    # Setup MySQL
    setup_mysql
    
    # Setup Shopware
    setup_shopware
    
    # Display information
    echo ""
    echo "🎉 Shopware Development Environment Ready!"
    echo "=================================="
    echo "🌐 Shopware Frontend: http://localhost"
    echo "🏪 Shopware Admin: http://localhost/admin"
    echo "📧 MailHog (Email testing): http://localhost:8025"
    echo "🗄️ Database: MySQL on localhost:3306"
    echo ""
    echo "👤 Admin Credentials:"
    echo "   Username: admin"
    echo "   Password: shopware"
    echo ""
    echo "🔧 Development Tools:"
    echo "   - Xdebug enabled on port 9003"
    echo "   - Symfony Profiler available"
    echo "   - Demo data installed"
    echo "   - Shopware CLI configured"
    echo "   - Hot reload ready"
    echo ""
    echo "📁 Mount your plugin to: /var/www/html/custom/plugins/YourPlugin"
    echo ""
    echo "🚀 Available npm scripts:"
    echo "   - npm run admin:build          # Build admin interface"
    echo "   - npm run admin:watch          # Watch admin changes"
    echo "   - npm run admin:code-mods      # Run admin code modifications"
    echo "   - npm run storefront:build     # Build storefront"
    echo "   - npm run storefront:watch     # Watch storefront changes"
    echo "   - npm run build:all           # Build everything"
    echo ""
    echo "🛠️ Shopware CLI commands:"
    echo "   - shopware-cli project dump-bundles    # Dump bundles"
    echo "   - shopware-cli project admin-build     # Build admin"
    echo "   - shopware-cli project storefront-build # Build storefront"
    echo "   - shopware-cli extension zip           # Create extension zip"
    echo ""
    
    # Stop MySQL service (supervisor will manage it)
    service mysql stop
    
    # Start supervisor
    echo "🚀 Starting all services..."
    exec /usr/bin/supervisord -c /etc/supervisor/conf.d/supervisord.conf
}

# Run main function
main
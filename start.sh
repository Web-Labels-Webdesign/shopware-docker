#!/bin/bash
set -e

echo "🚀 Starting Shopware Development Environment..."

# Create log directories with proper permissions
mkdir -p /var/log/supervisor
chown -R shopware:shopware /var/log/supervisor

# Create MySQL user home directory
mkdir -p /var/lib/mysql-home
chown mysql:mysql /var/lib/mysql-home
usermod -d /var/lib/mysql-home mysql

# Ensure MySQL directories exist with proper permissions
mkdir -p /var/lib/mysql /var/run/mysqld /var/log/mysql
chown -R mysql:mysql /var/lib/mysql /var/run/mysqld /var/log/mysql

# Initialize MySQL if needed
if [ ! -d "/var/lib/mysql/mysql" ]; then
    echo "📦 Initializing MySQL database..."
    # Initialize MySQL without SSL certificates to avoid security alerts
    mysqld --initialize-insecure --user=mysql --datadir=/var/lib/mysql --skip-ssl
    echo "✅ MySQL database initialized without SSL"
fi

# Clean up any SSL keys that might have been generated during initialization
echo "🔒 Ensuring no SSL keys are present in the image..."
rm -f /var/lib/mysql/ca-key.pem /var/lib/mysql/server-key.pem /var/lib/mysql/private_key.pem /var/lib/mysql/client-key.pem /var/lib/mysql/ca.pem /var/lib/mysql/server-cert.pem /var/lib/mysql/client-cert.pem /var/lib/mysql/public_key.pem 2>/dev/null || true

# Start MySQL service
echo "🗄️ Starting MySQL..."

# Try starting MySQL and check for success
if service mysql start; then
    echo "✅ MySQL service started successfully"
else
    echo "❌ MySQL service failed to start"
    echo "Checking MySQL error log:"
    tail -20 /var/log/mysql/error.log 2>/dev/null || echo "No MySQL error log found"
    
    # Try to restart MySQL
    echo "🔄 Attempting to restart MySQL..."
    service mysql stop 2>/dev/null || true
    sleep 2
    
    if service mysql start; then
        echo "✅ MySQL restarted successfully"
    else
        echo "❌ MySQL restart failed"
        exit 1
    fi
fi

# Wait for MySQL to be ready
echo "⏳ Waiting for MySQL to be ready..."
for i in {1..30}; do
    if mysqladmin ping -h localhost --silent 2>/dev/null; then
        echo "✅ MySQL is ready and responding"
        break
    fi
    echo "Waiting for MySQL... ($i/30)"
    sleep 2
done

# Final check if MySQL is actually running
if ! mysqladmin ping -h localhost --silent 2>/dev/null; then
    echo "❌ MySQL failed to become ready"
    echo "MySQL process status:"
    ps aux | grep mysql || echo "No MySQL processes found"
    echo "MySQL error log:"
    tail -20 /var/log/mysql/error.log 2>/dev/null || echo "No MySQL error log found"
    exit 1
fi

# Create Shopware database and user if they don't exist
echo "🔧 Setting up Shopware database..."
mysql -u root <<EOF
CREATE DATABASE IF NOT EXISTS shopware;
CREATE USER IF NOT EXISTS 'shopware'@'localhost' IDENTIFIED BY 'shopware';
GRANT ALL PRIVILEGES ON shopware.* TO 'shopware'@'localhost';
FLUSH PRIVILEGES;
EOF

# Test database connection
echo "🔍 Testing database connection..."
if ! mysql -u shopware -pshopware -e "SELECT 1;" shopware >/dev/null 2>&1; then
    echo "❌ Failed to connect to MySQL as shopware user"
    echo "Trying to recreate user..."
    mysql -u root <<EOF
DROP USER IF EXISTS 'shopware'@'localhost';
CREATE USER 'shopware'@'localhost' IDENTIFIED BY 'shopware';
GRANT ALL PRIVILEGES ON shopware.* TO 'shopware'@'localhost';
FLUSH PRIVILEGES;
EOF
fi

# Navigate to Shopware directory
cd /var/www/html

# Generate comprehensive .env.local configuration
echo "🔑 Setting up Shopware configuration..."

# Function to ensure environment variable is set
ensure_env_var() {
    local var_name="$1"
    local var_value="$2"
    
    if ! grep -q "^${var_name}=" .env.local 2>/dev/null; then
        echo "${var_name}=${var_value}" >> .env.local
    fi
}

# Initialize .env.local if it doesn't exist
if [ ! -f .env.local ]; then
    touch .env.local
fi

# Generate secrets (reuse existing if available)
if grep -q "JWT_PRIVATE_KEY_PASSPHRASE=" .env.local 2>/dev/null; then
    JWT_PASSPHRASE=$(grep "JWT_PRIVATE_KEY_PASSPHRASE=" .env.local | cut -d'=' -f2)
else
    JWT_PASSPHRASE=$(openssl rand -base64 32)
fi

if grep -q "APP_SECRET=" .env.local 2>/dev/null; then
    APP_SECRET=$(grep "APP_SECRET=" .env.local | cut -d'=' -f2)
else
    APP_SECRET=$(openssl rand -hex 32)
fi

if grep -q "INSTANCE_ID=" .env.local 2>/dev/null; then
    INSTANCE_ID=$(grep "INSTANCE_ID=" .env.local | cut -d'=' -f2)
else
    INSTANCE_ID=$(openssl rand -hex 16)
fi

# Ensure all required environment variables are present
ensure_env_var "APP_ENV" "dev"
ensure_env_var "APP_DEBUG" "1"
ensure_env_var "APP_URL" "http://localhost"
ensure_env_var "DATABASE_URL" "mysql://shopware:shopware@localhost:3306/shopware"
ensure_env_var "APP_SECRET" "${APP_SECRET}"
ensure_env_var "JWT_PRIVATE_KEY_PASSPHRASE" "${JWT_PASSPHRASE}"
ensure_env_var "INSTANCE_ID" "${INSTANCE_ID}"
ensure_env_var "SHOPWARE_ADMIN_BUILD_ONLY_EXTENSIONS" "1"
ensure_env_var "DISABLE_ADMIN_COMPILATION_TYPECHECK" "1"
ensure_env_var "SHOPWARE_SKIP_BUNDLE_DUMP" "1"
ensure_env_var "SHOPWARE_SKIP_ASSET_COPY" "1"
ensure_env_var "SHOPWARE_HTTP_CACHE_ENABLED" "0"
ensure_env_var "SHOPWARE_HTTP_DEFAULT_TTL" "7200"
ensure_env_var "SHOPWARE_ES_ENABLED" "0"
ensure_env_var "MAILER_URL" "smtp://localhost:1025"
ensure_env_var "SESSION_COOKIE_SECURE" "0" 
ensure_env_var "SESSION_COOKIE_SAMESITE" "lax"
ensure_env_var "TRUSTED_PROXIES" "127.0.0.1,REMOTE_ADDR"
ensure_env_var "TRUSTED_HOSTS" "localhost,127.0.0.1"
ensure_env_var "SHOPWARE_CDN_STRATEGY_DEFAULT" "id"
ensure_env_var "SHOPWARE_UPDATE_TEST" "0"
ensure_env_var "XDEBUG_ENABLED" "1"
ensure_env_var "PUPPETEER_SKIP_CHROMIUM_DOWNLOAD" "1"
ensure_env_var "LOCK_DSN" "flock"
ensure_env_var "REDIS_URL" "redis://localhost:6379"
ensure_env_var "SYMFONY_DEPRECATIONS_HELPER" "disabled"
ensure_env_var "OPENSEARCH_URL" ""
ensure_env_var "ELASTICSEARCH_URL" ""
ensure_env_var "SHOPWARE_DBAL_TIMEZONE_SUPPORT_ENABLED" "1"
ensure_env_var "SHOPWARE_DBAL_TOKEN_MINIMUM_LENGTH" "3"
ensure_env_var "BLUE_GREEN_DEPLOYMENT" "0"
ensure_env_var "DISABLE_EXTENSIONS_UPLOAD" "0"

echo "✅ Configuration file .env.local updated successfully"

# Install/Update Shopware if needed
if [ ! -f install.lock ]; then
    echo "🛠️ Installing Shopware..."
    
    # Clear cache first
    echo "🧹 Clearing cache..."
    su -c "php bin/console cache:clear --env=dev" shopware
    
    # Test database connection before installation
    echo "🔍 Testing database connection before installation..."
    if ! su -c "php bin/console dbal:run-sql 'SELECT 1'" shopware >/dev/null 2>&1; then
        echo "❌ Cannot connect to database. Check DATABASE_URL in .env"
        echo "Current DATABASE_URL: $(grep DATABASE_URL .env.local || echo 'Not found')"
        exit 1
    fi
    
    # Install Shopware
    echo "📦 Installing Shopware system..."
    if ! su -c "php bin/console system:install --create-database --basic-setup --force" shopware; then
        echo "❌ Shopware installation failed"
        echo "Check the error above and database connection"
        exit 1
    fi
    
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
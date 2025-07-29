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
echo "🔧 Setting up MySQL directories..."
mkdir -p /var/lib/mysql /var/run/mysqld /var/log/mysql
chown -R mysql:mysql /var/lib/mysql /var/run/mysqld /var/log/mysql
chmod 755 /var/lib/mysql /var/run/mysqld /var/log/mysql

# Debug: Check directory permissions
echo "MySQL directory permissions:"
ls -la /var/lib/ | grep mysql
ls -la /var/run/ | grep mysql

# Initialize MySQL if needed
if [ ! -d "/var/lib/mysql/mysql" ]; then
    echo "📦 Initializing MySQL database..."
    
    # Set MySQL initialization variables
    MYSQL_LOG="/tmp/mysql_init.log"
    
    # Check if MySQL is already running
    if pgrep mysqld > /dev/null; then
        echo "⚠️ MySQL process already running, stopping it first..."
        pkill mysqld || true
        sleep 2
    fi
    
    # Clean up existing MySQL data that might be from package installation
    echo "🧹 Cleaning existing MySQL data..."
    rm -rf /var/lib/mysql/*
    
    # Ensure directories are properly set up (dockware approach)
    mkdir -p /var/lib/mysql /var/run/mysqld /var/log/mysql
    chown -R mysql:mysql /var/lib/mysql /var/run/mysqld /var/log/mysql
    chmod 755 /var/lib/mysql /var/run/mysqld
    
    # Remove any socket lock files (dockware optimization)
    rm -f /var/run/mysqld/mysqld.sock.lock /var/lib/mysql/mysql.sock.lock 2>/dev/null || true
    
    # Create MySQL configuration for initialization (MySQL 8.0 compatible)
    cat > /tmp/mysql-init.cnf << 'EOF'
[mysqld]
datadir=/var/lib/mysql
socket=/var/run/mysqld/mysqld.sock
user=mysql
# Use tls-version='' instead of skip-ssl for MySQL 8.0
tls-version=''
skip-networking
bind-address=127.0.0.1
pid-file=/var/run/mysqld/mysqld.pid
log-error=/var/log/mysql/error.log
# MySQL 8.0 compatible sql_mode (NO_AUTO_CREATE_USER removed in 8.0)
sql_mode=STRICT_TRANS_TABLES,ERROR_FOR_DIVISION_BY_ZERO,NO_ENGINE_SUBSTITUTION
# Additional MySQL 8.0 optimizations
default-authentication-plugin=mysql_native_password
innodb_buffer_pool_size=256M
innodb_log_file_size=64M
max_allowed_packet=64M
EOF

    # Create necessary directories
    mkdir -p /var/run/mysqld /var/log/mysql
    chown mysql:mysql /var/run/mysqld /var/log/mysql
    chmod 755 /var/run/mysqld
    
    # Initialize MySQL with proper configuration
    echo "Running: mysqld --defaults-file=/tmp/mysql-init.cnf --initialize-insecure"
    
    if timeout 120 mysqld --defaults-file=/tmp/mysql-init.cnf --initialize-insecure > "$MYSQL_LOG" 2>&1; then
        echo "✅ MySQL database initialized successfully"
        echo "MySQL initialization log (last 10 lines):"
        tail -10 "$MYSQL_LOG" 2>/dev/null || echo "No log available"
    else
        echo "❌ MySQL initialization failed"
        echo "MySQL initialization log:"
        cat "$MYSQL_LOG" 2>/dev/null || echo "No log file found"
        
        # Check MySQL error log
        echo "MySQL error log:"
        tail -20 /var/log/mysql/error.log 2>/dev/null || echo "No error log found"
        
        # Try alternative initialization method
        echo "🔄 Trying alternative initialization..."
        rm -rf /var/lib/mysql/*
        
        # Use mysql_install_db if available (older method)
        if command -v mysql_install_db >/dev/null 2>&1; then
            echo "Using mysql_install_db..."
            if mysql_install_db --user=mysql --datadir=/var/lib/mysql --rpm --skip-name-resolve --skip-test-db > "$MYSQL_LOG" 2>&1; then
                echo "✅ MySQL initialized with mysql_install_db"
            else
                echo "❌ mysql_install_db also failed"
                cat "$MYSQL_LOG" 2>/dev/null || echo "No log available"
                exit 1
            fi
        else
            echo "❌ All MySQL initialization methods failed"
            echo "System information:"
            cat /etc/os-release | head -5
            echo "MySQL packages installed:"
            dpkg -l | grep mysql || echo "No MySQL packages found"
            exit 1
        fi
    fi
    
    # Fix system MySQL configuration files to remove MySQL 5.7 incompatible settings
    echo "🔧 Fixing system MySQL configuration for MySQL 8.0 compatibility..."
    
    # Remove NO_AUTO_CREATE_USER from all MySQL configuration files
    find /etc/mysql -name "*.cnf" -type f -exec sed -i 's/,NO_AUTO_CREATE_USER//g' {} \; 2>/dev/null || true
    find /etc/mysql -name "*.cnf" -type f -exec sed -i 's/NO_AUTO_CREATE_USER,//g' {} \; 2>/dev/null || true
    find /etc/mysql -name "*.cnf" -type f -exec sed -i 's/NO_AUTO_CREATE_USER//g' {} \; 2>/dev/null || true
    
    # Replace skip-ssl with tls-version in all config files
    find /etc/mysql -name "*.cnf" -type f -exec sed -i 's/skip-ssl/tls-version=/g' {} \; 2>/dev/null || true
    
    # Create our override configuration
    mkdir -p /etc/mysql/conf.d
    cat > /etc/mysql/conf.d/shopware-override.cnf << 'EOF'
[mysqld]
# MySQL 8.0 compatible configuration - highest priority
sql_mode=STRICT_TRANS_TABLES,ERROR_FOR_DIVISION_BY_ZERO,NO_ENGINE_SUBSTITUTION
tls-version=''
default-authentication-plugin=mysql_native_password
innodb_buffer_pool_size=256M
max_allowed_packet=64M
# Disable problematic options
skip-ssl=0
EOF

    # Clean up temporary config
    rm -f /tmp/mysql-init.cnf
    
    # Cleanup log file
    rm -f "$MYSQL_LOG"
fi

# Clean up any SSL keys that might have been generated during initialization
echo "🔒 Ensuring no SSL keys are present in the image..."
rm -f /var/lib/mysql/ca-key.pem /var/lib/mysql/server-key.pem /var/lib/mysql/private_key.pem /var/lib/mysql/client-key.pem /var/lib/mysql/ca.pem /var/lib/mysql/server-cert.pem /var/lib/mysql/client-cert.pem /var/lib/mysql/public_key.pem 2>/dev/null || true

# Start MySQL service
echo "🗄️ Starting MySQL..."

# Ensure required directories exist with proper permissions (dockware approach)
mkdir -p /var/run/mysqld /var/log/mysql
chown -R mysql:mysql /var/lib/mysql /var/run/mysqld /var/log/mysql
chmod 755 /var/run/mysqld

# Remove socket lock files before starting (dockware optimization)
rm -f /var/run/mysqld/mysqld.sock.lock /var/lib/mysql/mysql.sock.lock 2>/dev/null || true

# Apply MySQL 8.0 configuration fixes before starting service
echo "🔧 Applying MySQL 8.0 configuration fixes..."

# Backup and replace main MySQL configuration
if [ -f /etc/mysql/my.cnf ]; then
    cp /etc/mysql/my.cnf /etc/mysql/my.cnf.backup 2>/dev/null || true
fi

# Create a clean MySQL 8.0 compatible configuration
cat > /etc/mysql/my.cnf << 'EOF'
[mysql]
default-character-set = utf8mb4

[mysqld]
# Basic configuration
user = mysql
bind-address = 127.0.0.1
port = 3306
datadir = /var/lib/mysql
socket = /var/run/mysqld/mysqld.sock
pid-file = /var/run/mysqld/mysqld.pid
log-error = /var/log/mysql/error.log

# MySQL 8.0 compatible settings
sql_mode = STRICT_TRANS_TABLES,ERROR_FOR_DIVISION_BY_ZERO,NO_ENGINE_SUBSTITUTION
tls-version = ''
default-authentication-plugin = mysql_native_password

# Performance tuning for Shopware
innodb_buffer_pool_size = 256M
max_allowed_packet = 64M
innodb_log_buffer_size = 16M
innodb_flush_method = O_DIRECT
innodb_file_per_table = 1

# Character set
character-set-server = utf8mb4
collation-server = utf8mb4_unicode_ci

[mysqld_safe]
socket = /var/run/mysqld/mysqld.sock
nice = 0

[client]
default-character-set = utf8mb4
socket = /var/run/mysqld/mysqld.sock
EOF

# Remove any conflicting configuration files
rm -f /etc/mysql/conf.d/*sql_mode* 2>/dev/null || true

# Try starting MySQL and check for success
if service mysql start; then
    echo "✅ MySQL service started successfully"
else
    echo "❌ MySQL service failed to start"
    echo "Checking MySQL error log:"
    tail -20 /var/log/mysql/error.log 2>/dev/null || echo "No MySQL error log found"
    
    # Check if MySQL socket directory exists
    echo "Checking MySQL socket directory:"
    ls -la /var/run/mysqld/ 2>/dev/null || echo "Socket directory not found"
    
    # Try to fix permissions and restart MySQL
    echo "🔧 Fixing permissions and attempting restart..."
    chown -R mysql:mysql /var/lib/mysql /var/run/mysqld /var/log/mysql
    chmod -R 755 /var/lib/mysql
    service mysql stop 2>/dev/null || true
    sleep 3
    
    if service mysql start; then
        echo "✅ MySQL restarted successfully after permission fix"
    else
        echo "❌ MySQL restart failed after permission fix"
        echo "Final MySQL error log:"
        tail -30 /var/log/mysql/error.log 2>/dev/null || echo "No error log available"
        exit 1
    fi
fi

# Wait for MySQL to be ready (dockware-inspired approach)
echo "⏳ Waiting for MySQL to be ready..."
MYSQL_READY=false
for i in {1..30}; do
    # Try multiple ways to check MySQL readiness
    if mysqladmin ping -h localhost --silent 2>/dev/null; then
        echo "✅ MySQL is ready and responding"
        MYSQL_READY=true
        break
    elif mysql -u root -e "SELECT 1" >/dev/null 2>&1; then
        echo "✅ MySQL connection established"
        MYSQL_READY=true
        break
    fi
    echo "Waiting for MySQL... ($i/30)"
    sleep 2
done

# Final check if MySQL is actually running
if [ "$MYSQL_READY" = "false" ]; then
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
CREATE DATABASE IF NOT EXISTS shopware CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
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

# Check if Shopware is already installed (from build process)
if [ -f install.lock ]; then
    echo "✅ Shopware is already installed (from build process)"
    
    # Just ensure database connection and clear cache
    echo "🔍 Verifying database connection..."
    if ! mysql -u shopware -pshopware -e "SELECT 1;" shopware >/dev/null 2>&1; then
        echo "⚠️ Database user doesn't exist, recreating..."
        mysql -u root <<EOF
CREATE USER IF NOT EXISTS 'shopware'@'localhost' IDENTIFIED BY 'shopware';
GRANT ALL PRIVILEGES ON shopware.* TO 'shopware'@'localhost';
FLUSH PRIVILEGES;
EOF
    fi
    
    # Update database schema if needed
    su -c "php bin/console database:migrate --all --force" shopware
    
    # Clear runtime cache
    echo "🧹 Clearing runtime cache..."
    su -c "php bin/console cache:clear --env=dev" shopware || echo "Cache clear failed - continuing anyway"
    
else
    echo "⚠️ Shopware not installed during build - performing runtime installation (slower)"
    
    # Fallback installation if build process didn't complete
    # Test database connection before installation
    echo "🔍 Testing database connection before installation..."
    
    # First test basic MySQL connection
    if ! mysql -u shopware -pshopware -e "SELECT 1;" shopware >/dev/null 2>&1; then
        echo "❌ Cannot connect to MySQL database with shopware user"
        echo "Trying to fix database setup..."
        
        # Recreate database and user
        mysql -u root <<EOF
DROP DATABASE IF EXISTS shopware;
CREATE DATABASE shopware CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
DROP USER IF EXISTS 'shopware'@'localhost';
CREATE USER 'shopware'@'localhost' IDENTIFIED BY 'shopware';
GRANT ALL PRIVILEGES ON shopware.* TO 'shopware'@'localhost';
FLUSH PRIVILEGES;
EOF
        
        # Test again
        if ! mysql -u shopware -pshopware -e "SELECT 1;" shopware >/dev/null 2>&1; then
            echo "❌ Still cannot connect to database after recreation"
            echo "Current DATABASE_URL: $(grep DATABASE_URL .env.local || echo 'Not found')"
            exit 1
        else
            echo "✅ Database connection fixed"
        fi
    else
        echo "✅ Database connection successful"
    fi
    
    # Install Shopware
    echo "📦 Installing Shopware system..."
    if ! su -c "php bin/console system:install --basic-setup --force" shopware; then
        echo "❌ Shopware installation failed"
        echo "Check the error above and database connection"
        exit 1
    fi
    
    # Create admin user
    su -c "php bin/console user:create admin --admin --email=\"admin@example.com\" --firstName=\"Shop\" --lastName=\"Admin\" --password=\"shopware\"" shopware || echo "Admin user might already exist"
    
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
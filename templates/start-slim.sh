#!/bin/bash
# Slim Shopware Container Startup Script
# Minimal services for lightweight development

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}🚀 Starting Shopware ${SHOPWARE_VERSION} (Slim)${NC}"
echo "=================================================="

# Ensure we're running as the shopware user for application files
if [ "$(id -u)" = "0" ]; then
    echo -e "${YELLOW}⚠️ Running as root, switching to shopware user for application${NC}"
    exec gosu shopware "$0" "$@"
fi

# Set proper permissions
echo -e "${BLUE}🔧 Setting up permissions${NC}"
sudo chown -R shopware:shopware /var/www/html
sudo chmod -R 775 /var/www/html/var
sudo chmod -R 775 /var/www/html/public
sudo chmod -R 775 /var/www/html/files
sudo chmod -R 775 /var/www/html/custom

# Environment validation
echo -e "${BLUE}🔍 Validating environment${NC}"
if [ ! -f ".env.local" ]; then
    echo -e "${RED}❌ Missing .env.local file${NC}"
    exit 1
fi

# Optimize for production
echo -e "${BLUE}⚡ Optimizing for production${NC}"
if [ ! -f "var/cache/.containerized" ]; then
    echo -e "${YELLOW}  • Warming up cache${NC}"
    php bin/console cache:warmup --env=prod >/dev/null 2>&1 || true
    
    echo -e "${YELLOW}  • Optimizing autoloader${NC}"
    composer dump-autoload --optimize --no-dev >/dev/null 2>&1 || true
    
    touch var/cache/.containerized
fi

# Health check endpoint
echo -e "${BLUE}🏥 Setting up health check${NC}"
cat > public/health.php << 'EOF'
<?php
// Simple health check for slim variant
header('Content-Type: application/json');
http_response_code(200);
echo json_encode([
    'status' => 'healthy',
    'variant' => 'slim',
    'php_version' => PHP_VERSION,
    'timestamp' => date('c')
]);
EOF

# Configure PHP-FPM for slim variant
echo -e "${BLUE}🐘 Configuring PHP-FPM${NC}"
sudo tee /etc/php/${PHP_VERSION}/fpm/pool.d/www.conf > /dev/null << EOF
[www]
user = shopware
group = shopware
listen = 0.0.0.0:9000
listen.owner = shopware
listen.group = shopware
pm = dynamic
pm.max_children = 10
pm.start_servers = 2
pm.min_spare_servers = 1
pm.max_spare_servers = 3
pm.process_idle_timeout = 10s
pm.max_requests = 500
pm.status_path = /status
ping.path = /ping
catch_workers_output = yes
clear_env = no
EOF

echo -e "${GREEN}✅ Shopware ${SHOPWARE_VERSION} (Slim) ready${NC}"
echo -e "${BLUE}🌐 PHP-FPM listening on port 9000${NC}"
echo -e "${BLUE}🏥 Health check: /health.php${NC}"
echo -e "${BLUE}📊 Status: /status${NC}"
echo "=================================================="

# Start supervisor to manage PHP-FPM
exec sudo /usr/bin/supervisord -c /etc/supervisor/conf.d/supervisord.conf
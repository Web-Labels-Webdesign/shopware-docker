#!/bin/bash
# Quick setup script for Shopware Development Docker
# Usage: ./setup.sh [project-name] [shopware-version]

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
PROJECT_NAME=${1:-"shopware-project"}
SHOPWARE_VERSION=${2:-"6.7.1.0"}
VARIANT=${3:-"full"}
REGISTRY="ghcr.io/web-labels-webdesign/shopware-docker/shopware-dev"

# Available versions with PHP compatibility
declare -A VERSIONS=(
    ["6.5.8.18"]="8.2"
    ["6.6.10.6"]="8.3"
    ["6.7.1.0"]="8.4"
)

# Available variants
declare -A VARIANTS=(
    ["full"]="Complete development environment with all services"
    ["slim"]="Lightweight environment for CI/CD and minimal setups"
)

print_logo() {
    echo -e "${BLUE}"
    echo "╔═══════════════════════════════════════╗"
    echo "║        Shopware Development           ║"
    echo "║         Docker Setup                  ║"
    echo "╚═══════════════════════════════════════╝"
    echo -e "${NC}"
}

print_help() {
    echo "Usage: $0 [project-name] [shopware-version] [variant]"
    echo ""
    echo "Arguments:"
    echo "  project-name      Name of your project directory (default: shopware-project)"
    echo "  shopware-version  Shopware version to use (default: 6.7.1.0)"
    echo "  variant          Container variant to use (default: full)"
    echo ""
    echo "Available versions:"
    for version in "${!VERSIONS[@]}"; do
        php_version=${VERSIONS[$version]}
        echo "  • $version (PHP $php_version)"
    done
    echo ""
    echo "Available variants:"
    for variant in "${!VARIANTS[@]}"; do
        description=${VARIANTS[$variant]}
        echo "  • $variant: $description"
    done
    echo ""
    echo "Examples:"
    echo "  $0                              # Create 'shopware-project' with latest full"
    echo "  $0 my-shop                      # Create 'my-shop' with latest full"
    echo "  $0 my-shop 6.6.10.6            # Create 'my-shop' with specific version"
    echo "  $0 my-shop 6.7.1.0 slim        # Create 'my-shop' with slim variant"
    echo ""
}

validate_version() {
    if [[ ! " ${!VERSIONS[@]} " =~ " ${SHOPWARE_VERSION} " ]]; then
        echo -e "${RED}❌ Invalid Shopware version: $SHOPWARE_VERSION${NC}"
        echo "Available versions: ${!VERSIONS[@]}"
        exit 1
    fi
}

validate_variant() {
    if [[ ! " ${!VARIANTS[@]} " =~ " ${VARIANT} " ]]; then
        echo -e "${RED}❌ Invalid variant: $VARIANT${NC}"
        echo "Available variants: ${!VARIANTS[@]}"
        exit 1
    fi
}

check_requirements() {
    echo -e "${BLUE}🔍 Checking requirements...${NC}"
    
    # Check Docker
    if ! command -v docker &> /dev/null; then
        echo -e "${RED}❌ Docker is not installed${NC}"
        echo "Please install Docker: https://docs.docker.com/get-docker/"
        exit 1
    fi
    
    # Check Docker Compose
    if ! command -v docker-compose &> /dev/null && ! docker compose version &> /dev/null; then
        echo -e "${RED}❌ Docker Compose is not installed${NC}"
        echo "Please install Docker Compose: https://docs.docker.com/compose/install/"
        exit 1
    fi
    
    # Check if Docker is running
    if ! docker info &> /dev/null; then
        echo -e "${RED}❌ Docker is not running${NC}"
        echo "Please start Docker daemon"
        exit 1
    fi
    
    echo -e "${GREEN}✅ All requirements met${NC}"
}

create_project() {
    echo -e "${BLUE}📁 Creating project directory: $PROJECT_NAME${NC}"
    
    if [ -d "$PROJECT_NAME" ]; then
        echo -e "${YELLOW}⚠️ Directory $PROJECT_NAME already exists${NC}"
        read -p "Do you want to continue? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            echo "Aborted."
            exit 1
        fi
    else
        mkdir -p "$PROJECT_NAME"
    fi
    
    cd "$PROJECT_NAME"
}

create_docker_compose() {
    echo -e "${BLUE}🐳 Creating docker-compose.yml for $VARIANT variant...${NC}"
    
    # Determine image tag based on variant
    IMAGE_TAG="${SHOPWARE_VERSION}"
    if [ "$VARIANT" = "slim" ]; then
        IMAGE_TAG="${SHOPWARE_VERSION}-slim"
    fi
    
    if [ "$VARIANT" = "slim" ]; then
        # Slim variant compose file
        cat > docker-compose.yml << EOF
version: '3.8'

services:
  shopware:
    image: ${REGISTRY}:${IMAGE_TAG}
    container_name: ${PROJECT_NAME}_shopware_slim
    ports:
      - "9000:9000"  # PHP-FPM
    volumes:
      # Mount your custom code
      - "./custom/plugins:/var/www/html/custom/plugins"
      - "./custom/themes:/var/www/html/custom/themes"
      
      # Application data (minimal)
      - "shopware_var:/var/www/html/var"
      - "shopware_files:/var/www/html/files"
    
    environment:
      - VARIANT=slim
      - SHOPWARE_VERSION=${SHOPWARE_VERSION}
      - PHP_VERSION=${VERSIONS[$SHOPWARE_VERSION]}
    
    networks:
      - shopware
    
    # Health check for slim variant
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:9000/ping"]
      interval: 30s
      timeout: 5s
      retries: 3
      start_period: 30s

  # External services for slim variant
  nginx:
    image: nginx:alpine
    container_name: ${PROJECT_NAME}_nginx
    ports:
      - "80:80"
    volumes:
      - "./nginx.conf:/etc/nginx/nginx.conf:ro"
      - "shopware_public:/var/www/html/public"
    depends_on:
      - shopware
    networks:
      - shopware

volumes:
  shopware_var:
    driver: local
  shopware_files:
    driver: local
  shopware_public:
    driver: local

networks:
  shopware:
    driver: bridge
EOF
    else
        # Full variant compose file  
        cat > docker-compose.yml << EOF
version: '3.8'

services:
  shopware:
    image: ${REGISTRY}:${IMAGE_TAG}
    container_name: ${PROJECT_NAME}_shopware
    ports:
      - "80:80"      # Shopware Frontend & Admin
      - "443:443"    # HTTPS (optional)
      - "3306:3306"  # MySQL Database
      - "8025:8025"  # MailHog Web UI
      - "9003:9003"  # Xdebug
    volumes:
      # Mount your custom plugins
      - "./custom/plugins:/var/www/html/custom/plugins"

      # Mount your custom themes
      - "./custom/themes:/var/www/html/custom/themes"

      # Optional: Persist database data
      - "mysql_data:/var/lib/mysql"

      # Optional: Persist media files
      - "shopware_media:/var/www/html/public/media"

      # Optional: Persist uploaded files
      - "shopware_files:/var/www/html/files"

    environment:
      # Xdebug configuration
      - XDEBUG_ENABLED=1
      - XDEBUG_REMOTE_HOST=host.docker.internal

      # Shopware development settings
      - PUPPETEER_SKIP_CHROMIUM_DOWNLOAD=1
      - SHOPWARE_ADMIN_BUILD_ONLY_EXTENSIONS=1
      - DISABLE_ADMIN_COMPILATION_TYPECHECK=1

      # Custom APP_URL (change if needed)
      - APP_URL=http://localhost
      
      # Variant configuration
      - VARIANT=full
      - SHOPWARE_VERSION=${SHOPWARE_VERSION}
      - PHP_VERSION=${VERSIONS[$SHOPWARE_VERSION]}

    networks:
      - shopware

    # Health check
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost/api/_info/version"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 90s

volumes:
  mysql_data:
    driver: local
  shopware_media:
    driver: local
  shopware_files:
    driver: local

networks:
  shopware:
    driver: bridge
EOF
    fi
}

create_directories() {
    echo -e "${BLUE}📂 Creating project structure...${NC}"
    
    mkdir -p custom/plugins
    mkdir -p custom/themes
    mkdir -p custom/apps
    
    # Create example plugin structure
    mkdir -p custom/plugins/ExamplePlugin/src
    
    cat > custom/plugins/ExamplePlugin/composer.json << 'EOF'
{
    "name": "example/example-plugin",
    "description": "Example Shopware 6 Plugin",
    "type": "shopware-plugin",
    "license": "MIT",
    "autoload": {
        "psr-4": {
            "Example\\ExamplePlugin\\": "src/"
        }
    },
    "extra": {
        "shopware-plugin-class": "Example\\ExamplePlugin\\ExamplePlugin",
        "label": {
            "de-DE": "Beispiel Plugin",
            "en-GB": "Example Plugin"
        }
    }
}
EOF
    
    cat > custom/plugins/ExamplePlugin/src/ExamplePlugin.php << 'EOF'
<?php declare(strict_types=1);

namespace Example\ExamplePlugin;

use Shopware\Core\Framework\Plugin;

class ExamplePlugin extends Plugin
{
}
EOF
}

create_gitignore() {
    echo -e "${BLUE}📝 Creating .gitignore...${NC}"
    
    cat > .gitignore << 'EOF'
# Docker volumes
mysql_data/
shopware_media/
shopware_files/

# IDE files
.vscode/
.idea/
*.swp
*.swo

# OS files
.DS_Store
Thumbs.db

# Logs
*.log

# Environment files (if you create custom ones)
.env.local
.env.*.local

# Temporary files
*.tmp
*.temp
EOF
}

create_readme() {
    echo -e "${BLUE}📚 Creating README.md...${NC}"
    
    cat > README.md << EOF
# ${PROJECT_NAME}

Shopware ${SHOPWARE_VERSION} development environment using Docker.

## 🚀 Quick Start

\`\`\`bash
# Start the development environment
docker-compose up -d

# Check status
docker-compose ps

# View logs
docker-compose logs -f shopware
\`\`\`

## 🌐 Access Points

- **Shopware Frontend:** http://localhost
- **Shopware Admin:** http://localhost/admin
- **MailHog (Email testing):** http://localhost:8025
- **Database:** localhost:3306

### Default Credentials
- **Admin Username:** \`admin\`
- **Admin Password:** \`shopware\`
- **Database User:** \`shopware\`
- **Database Password:** \`shopware\`

## 🛠️ Development Workflow

### Plugin Development
1. Create your plugin in \`custom/plugins/YourPlugin/\`
2. Refresh plugins: \`docker-compose exec shopware bin/console plugin:refresh\`
3. Install plugin: \`docker-compose exec shopware bin/console plugin:install --activate YourPlugin\`

### NPM Scripts
\`\`\`bash
# Build admin interface
docker-compose exec shopware npm run admin:build

# Watch admin changes
docker-compose exec shopware npm run admin:watch

# Build storefront
docker-compose exec shopware npm run storefront:build

# Run code modifications
docker-compose exec shopware npm run admin:code-mods
\`\`\`

### Shopware CLI
\`\`\`bash
# Extension development
docker-compose exec shopware shopware-cli extension zip
docker-compose exec shopware shopware-cli extension validate

# Project management
docker-compose exec shopware shopware-cli project dump-bundles
docker-compose exec shopware shopware-cli project admin-build
\`\`\`

## 🐛 Debugging

Xdebug is pre-configured and enabled. Configure your IDE:
- **Host:** localhost
- **Port:** 9003
- **Path mapping:** \`{project-root}\` → \`/var/www/html\`

## 🗄️ Database Management

\`\`\`bash
# Access MySQL
docker-compose exec shopware mysql -u shopware -pshopware shopware

# Backup database
docker-compose exec shopware mysqldump -u shopware -pshopware shopware > backup.sql

# Restore database
docker-compose exec -T shopware mysql -u shopware -pshopware shopware < backup.sql
\`\`\`

## 📁 Project Structure

\`\`\`
${PROJECT_NAME}/
├── custom/
│   ├── plugins/          # Your custom plugins
│   ├── themes/           # Your custom themes
│   └── apps/            # Your custom apps
├── docker-compose.yml   # Docker configuration
└── README.md           # This file
\`\`\`

## 🚀 Useful Commands

\`\`\`bash
# Start services
docker-compose up -d

# Stop services
docker-compose down

# Restart Shopware
docker-compose restart shopware

# Clear cache
docker-compose exec shopware bin/console cache:clear

# Update database
docker-compose exec shopware bin/console database:migrate --all

# Install demo data
docker-compose exec shopware bin/console framework:demodata
\`\`\`

## 📊 Performance Tips

- Disable Xdebug when not debugging: \`XDEBUG_ENABLED=0\`
- Use persistent volumes for database and media
- Allocate sufficient resources to Docker

## 🆘 Troubleshooting

- **Container won't start:** Check port conflicts and Docker resources
- **Database connection issues:** Wait for MySQL to fully initialize (60-90 seconds)
- **Permission errors:** Run \`docker-compose exec shopware chown -R www-data:www-data /var/www/html\`

---

Happy Shopware Development! 🛍️
EOF
}

create_scripts() {
    echo -e "${BLUE}🔧 Creating helper scripts...${NC}"
    
    # Create start script
    cat > start.sh << 'EOF'
#!/bin/bash
echo "🚀 Starting Shopware development environment..."
docker-compose up -d
echo "✅ Environment started!"
echo ""
echo "🌐 Frontend: http://localhost"
echo "🏪 Admin: http://localhost/admin"
echo "📧 MailHog: http://localhost:8025"
EOF
    chmod +x start.sh
    
    # Create stop script
    cat > stop.sh << 'EOF'
#!/bin/bash
echo "🛑 Stopping Shopware development environment..."
docker-compose down
echo "✅ Environment stopped!"
EOF
    chmod +x stop.sh
    
    # Create logs script
    cat > logs.sh << 'EOF'
#!/bin/bash
docker-compose logs -f shopware
EOF
    chmod +x logs.sh
    
    # Create shell script
    cat > shell.sh << 'EOF'
#!/bin/bash
docker-compose exec shopware bash
EOF
    chmod +x shell.sh
}

main() {
    # Parse arguments
    if [[ "$1" == "-h" || "$1" == "--help" ]]; then
        print_logo
        print_help
        exit 0
    fi
    
    print_logo
    
    echo -e "${BLUE}🎯 Project Setup${NC}"
    echo "Project Name: $PROJECT_NAME"
    echo "Shopware Version: $SHOPWARE_VERSION (PHP ${VERSIONS[$SHOPWARE_VERSION]})"
    echo "Variant: $VARIANT"
    echo ""
    
    # Validate inputs
    validate_version
    validate_variant
    
    # Check requirements
    check_requirements
    
    # Create project
    create_project
    create_docker_compose
    create_directories
    create_gitignore
    create_readme
    create_scripts
    
    echo ""
    echo -e "${GREEN}🎉 Project setup complete!${NC}"
    echo ""
    echo -e "${YELLOW}Next steps:${NC}"
    echo "1. cd $PROJECT_NAME"
    echo "2. ./start.sh                    # Start the environment"
    echo "3. Wait 60-90 seconds for setup  # First start takes longer"
    echo "4. Open http://localhost         # Access your shop"
    echo ""
    echo -e "${BLUE}Development commands:${NC}"
    echo "./start.sh                       # Start environment"
    echo "./stop.sh                        # Stop environment"
    echo "./logs.sh                        # View logs"
    echo "./shell.sh                       # Access container shell"
    echo ""
    echo -e "${GREEN}Happy Shopware Development! 🛍️${NC}"
}

# Run main function
main "$@"
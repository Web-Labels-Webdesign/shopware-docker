# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repository Overview

This is a Shopware 6 development Docker environment that provides a modern alternative to dockware. It creates production-ready Docker images for Shopware development with all necessary tools pre-configured.

## Build and Development Commands

### Building Docker Images
```bash
# Build all versions
./build.sh

# Build specific version
./build.sh 6.7.1.0

# Build for specific platform
./build.sh 6.7.1.0 linux/amd64
```

### Project Setup
```bash
# Quick project setup with default settings
./setup.sh

# Setup with custom project name and version
./setup.sh my-project 6.7.1.0
```

### Container Management
```bash
# Start development environment
docker-compose up -d

# Stop environment
docker-compose down

# View logs
docker-compose logs -f shopware

# Access container shell
docker-compose exec shopware bash
```

### Shopware Development Commands
```bash
# NPM build scripts (run inside container)
docker-compose exec shopware npm run admin:build          # Build admin interface
docker-compose exec shopware npm run admin:watch          # Watch admin changes
docker-compose exec shopware npm run admin:dev            # Development build
docker-compose exec shopware npm run storefront:build     # Build storefront
docker-compose exec shopware npm run storefront:watch     # Watch storefront changes
docker-compose exec shopware npm run build:all           # Build everything

# Shopware CLI commands
docker-compose exec shopware shopware-cli project dump-bundles
docker-compose exec shopware shopware-cli project admin-build
docker-compose exec shopware shopware-cli extension zip
docker-compose exec shopware shopware-cli extension validate

# Shopware console commands
docker-compose exec shopware bin/console cache:clear
docker-compose exec shopware bin/console plugin:refresh
docker-compose exec shopware bin/console plugin:install --activate PluginName
docker-compose exec shopware bin/console database:migrate --all
```

## Architecture and Structure

### Supported Versions
- **6.7.1.0** with PHP 8.4 (latest)
- **6.6.10.6** with PHP 8.3
- **6.5.8.18** with PHP 8.2

### Docker Image Architecture
- **Base**: Ubuntu 22.04
- **Web Server**: Apache 2.4 with optimized Shopware configuration
- **Database**: MySQL 8 with Shopware-tuned settings
- **PHP**: FPM with development extensions (Xdebug, etc.)
- **Node.js**: Version 22 for asset building
- **Additional Tools**: Shopware CLI, Composer 2, MailHog

### Directory Structure
```
shopware-docker/
├── 6.5/, 6.6/, 6.7/     # Version-specific Dockerfiles
│   ├── Dockerfile
│   ├── apache-shopware.conf
│   ├── start.sh
│   └── supervisord.conf
├── build.sh             # Multi-version build script
├── setup.sh             # Quick project setup script
└── README.md            # Comprehensive documentation
```

### Key Configuration Files
- **Dockerfile**: Multi-stage build with development dependencies
- **apache-shopware.conf**: Apache virtual host with Shopware optimizations
- **start.sh**: Container initialization script with MySQL and Shopware setup
- **supervisord.conf**: Process management for MySQL, Apache, PHP-FPM, MailHog

### Build Process
1. **build.sh** script manages multi-version Docker builds
2. Uses Docker Buildx for multi-platform support (amd64/arm64)
3. Automatically tags versions and pushes to GitHub Container Registry
4. Creates proper semantic version tags (e.g., 6.7.1.0, 6.7, latest)

### Development Features
- **Xdebug 3**: Pre-configured for debugging on port 9003
- **Hot Reload**: Automatic asset rebuilding during development
- **Demo Data**: Pre-installed sample products and categories
- **MailHog**: Email testing and debugging on port 8025
- **Symfony Profiler**: Performance and debugging insights
- **Development Mode**: APP_ENV=dev with optimized settings

### Container Startup Process
1. MySQL service initialization and database creation
2. Shopware installation with demo data (if not exists)
3. JWT secret and app secret generation
4. Admin user creation (admin/shopware)
5. Asset building (admin and storefront)
6. Permission setup for development
7. Service management via Supervisor

### Environment Variables
- `XDEBUG_ENABLED=1`: Enable/disable Xdebug
- `APP_URL`: Base URL for Shopware
- `DATABASE_URL`: Database connection string
- `SHOPWARE_ADMIN_BUILD_ONLY_EXTENSIONS=1`: Faster admin builds
- `DISABLE_ADMIN_COMPILATION_TYPECHECK=1`: Skip TypeScript checking

### Access Points
- **Frontend**: http://localhost
- **Admin**: http://localhost/admin (admin/shopware)
- **MailHog**: http://localhost:8025
- **Database**: localhost:3306 (shopware/shopware)
- **Xdebug**: Port 9003

### Plugin Development Workflow
1. Mount plugin directory to `/var/www/html/custom/plugins/YourPlugin`
2. Refresh plugins: `bin/console plugin:refresh`
3. Install and activate: `bin/console plugin:install --activate YourPlugin`
4. Use npm scripts for asset building during development
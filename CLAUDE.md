# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repository Overview

This is a Shopware 6 development Docker environment that provides a modern alternative to dockware. It creates production-ready Docker images for Shopware development with all necessary tools pre-configured.

### Key Features
- **Build-time installation**: Complete Shopware installation happens during Docker build for faster startup
- **Multi-stage builds**: Optimized Docker builds with clear separation of concerns
- **Development-focused**: Pre-configured with Xdebug, demo data, and development tools
- **Modern tooling**: Uses Mailpit instead of MailHog, latest PHP versions, and optimized configurations

### Architecture Changes (Latest Update)
The installation process has been moved from startup to build time:

**Before**: 
- Shopware installation happened during container startup
- Long startup times (2-5 minutes)
- Network dependencies during startup

**After**:
- Complete Shopware installation during Docker build
- Container startup in seconds
- Database backup/restore for fresh instances
- Pre-built assets and JWT secrets

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
- **Additional Tools**: Shopware CLI, Composer 2, Mailpit

### Directory Structure
```
shopware-docker/
├── Dockerfile           # Single unified Dockerfile for all versions
├── apache-shopware.conf # Apache virtual host configuration
├── supervisord.conf     # Process management configuration
├── start.sh             # Container initialization script
├── build.sh             # Multi-version build script
├── setup.sh             # Quick project setup script
└── README.md            # Comprehensive documentation
```

### Key Configuration Files
- **Dockerfile**: Single unified multi-stage build with development dependencies
- **apache-shopware.conf**: Apache virtual host with Shopware optimizations
- **start.sh**: Container initialization script with MySQL and Shopware setup
- **supervisord.conf**: Process management for MySQL, Apache, PHP-FPM, Mailpit

### Build Process
1. **build.sh** script manages multi-version Docker builds using a single Dockerfile
2. Uses build arguments to specify Shopware version and PHP version
3. Uses Docker Buildx for multi-platform support (amd64/arm64)
4. **GitHub Actions** automatically builds and pushes images on code changes
5. Creates proper semantic version tags (e.g., 6.7.1.0, 6.7, latest)
6. Includes security scanning with Trivy and automated testing

### Development Features
- **Xdebug 3**: Pre-configured for debugging on port 9003
- **Hot Reload**: Automatic asset rebuilding during development
- **Demo Data**: Pre-installed sample products and categories
- **Mailpit**: Email testing and debugging on port 8025
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

### GitHub Actions CI/CD
- **Automated Builds**: Triggers on push to main/develop branches
- **Multi-version Support**: Builds all supported Shopware versions simultaneously
- **Security Scanning**: Trivy vulnerability scanning for each image
- **Automated Testing**: Health checks for Shopware API, admin, and Mailpit
- **Registry Push**: Automatic push to GitHub Container Registry
- **Scheduled Builds**: Weekly builds on Sundays for security updates
- **Manual Triggers**: Support for building specific versions via workflow dispatch

### Environment Variables
All configuration is automatically set in `.env.local` during container startup:
- `APP_ENV=dev`: Development environment
- `DATABASE_URL`: MySQL connection (auto-configured)
- `APP_SECRET` & `JWT_PRIVATE_KEY_PASSPHRASE`: Auto-generated secrets
- `XDEBUG_ENABLED=1`: Enable/disable Xdebug
- `SHOPWARE_ADMIN_BUILD_ONLY_EXTENSIONS=1`: Faster admin builds
- `DISABLE_ADMIN_COMPILATION_TYPECHECK=1`: Skip TypeScript checking
- `MAILER_URL`: Mailpit SMTP configuration
- Plus 20+ additional optimized settings for development

### Access Points
- **Frontend**: http://localhost
- **Admin**: http://localhost/admin (admin/shopware)
- **Mailpit**: http://localhost:8025
- **Database**: localhost:3306 (shopware/shopware)
- **Xdebug**: Port 9003

### Plugin Development Workflow
1. Mount plugin directory to `/var/www/html/custom/plugins/YourPlugin`
2. Refresh plugins: `bin/console plugin:refresh`
3. Install and activate: `bin/console plugin:install --activate YourPlugin`
4. Use npm scripts for asset building during development
# Shopware 6 Docker Development Environment

This Docker setup provides a complete development environment for Shopware 6 with version selection capability.

## Services

- **Shopware**: PHP 8.2-FPM with Nginx
- **MySQL**: 8.0 database server
- **Redis**: Cache and session storage
- **Elasticsearch**: Search engine
- **MailHog**: Email testing
- **Adminer**: Database management

## Version Selection

This Docker setup supports the latest versions from the three most recent Shopware 6 minor branches:

### Supported Versions

| Shopware Version | PHP Version | Status | Notes |
|------------------|-------------|---------|-------|
| **6.7.1.1** | PHP 8.2 | Latest | Current major release |
| **6.6.10.6** | PHP 8.2 | Stable | Extended support version |
| **6.5.8.18** | PHP 8.1 | Legacy | End of life support |

### Configuration

Edit the `.env` file to select your desired version:

```bash
# For Shopware 6.7 (recommended)
SHOPWARE_VERSION=6.7.1.1
PHP_VERSION=8.2

# For Shopware 6.6 (stable)
SHOPWARE_VERSION=6.6.10.6
PHP_VERSION=8.2

# For Shopware 6.5 (legacy)
SHOPWARE_VERSION=6.5.8.18
PHP_VERSION=8.1
```

## Quick Start

### Option 1: Use Pre-built Images (Recommended)

```bash
# Use latest stable version (6.6.10.6)
docker-compose up -d

# Or specify a version
SHOPWARE_VERSION=6.7.1.1 docker-compose up -d
```

### Option 2: Build Locally

1. **Select Shopware version**:
   Edit `.env` file with your desired version and PHP version

2. **Build and start containers**:
```bash
docker-compose up -d --build
```

3. **Wait for services** (first build may take 5-10 minutes)

4. **Access the application**:
- Shopware: http://localhost
- Adminer: http://localhost:8080
- MailHog: http://localhost:8025

## Docker Images

Pre-built images are available at `ghcr.io/your-username/shopware-docker-v2`:

- `ghcr.io/your-username/shopware-docker-v2:6.7.1.1` - Shopware 6.7 with PHP 8.2
- `ghcr.io/your-username/shopware-docker-v2:6.6.10.6` - Shopware 6.6 with PHP 8.2
- `ghcr.io/your-username/shopware-docker-v2:6.5.8.18` - Shopware 6.5 with PHP 8.1
- `ghcr.io/your-username/shopware-docker-v2:latest` - Latest stable (6.6.10.6)

## GitHub Actions

This repository includes automated Docker image building via GitHub Actions:

- **Automatic builds** on push to main branch
- **Weekly rebuilds** every Sunday at 2 AM UTC
- **Manual builds** via workflow dispatch
- **Multi-platform support** (linux/amd64, linux/arm64)
- **Automatic tagging** with version numbers

## Configuration

- Database credentials: `shopware/shopware@shopware`
- Environment variables in `.env`
- PHP configuration in `docker/php/php.ini`
- Nginx configuration in `docker/nginx/default.conf`

## Development

- Shopware 6 is cloned from the base repository during build
- Version is checked out based on `SHOPWARE_VERSION` build argument
- Persistent data (var, files) are stored in Docker volumes
- Composer and npm dependencies are installed automatically

## Useful Commands

```bash
# View logs
docker-compose logs -f shopware

# Execute commands in container
docker-compose exec shopware bash

# Restart services
docker-compose restart

# Stop and remove containers
docker-compose down
```
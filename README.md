# Shopware Development Docker Images

A modern alternative to dockware for Shopware 6 development with all the latest versions and development tools pre-configured.

> **Last updated: 2025-07-29 07:46:22 UTC**

## 🚀 Quick Start

```bash
# Complete development environment with Apache, MySQL, Mailpit, and Xdebug
docker run -d \
  --name shopware-dev \
  -p 80:80 -p 3306:3306 -p 8025:8025 -p 9003:9003 \
  -v "./src:/var/www/html/custom/plugins/YourPlugin" \
  ghcr.io/weblabels/shopware-docker/shopware-dev:6.7.1.0

# Or use the setup script for a complete project
./setup.sh my-project 6.7.1.0
```

## 📋 Available Versions

| Shopware Version | PHP Version | Tag | Base Image | Status |
| ---------------- | ----------- | --- | ---------- | ------ |
| 6.7.1.0 | 8.4 | `6.7.1.0`, `6.7`, `latest` | Ubuntu 22.04 | ✅ Active |
| 6.6.10.6 | 8.3 | `6.6.10.6`, `6.6` | Ubuntu 22.04 | ✅ Active |
| 6.5.8.18 | 8.2 | `6.5.8.18`, `6.5` | Ubuntu 22.04 | ✅ Active |

### What's Included

**Complete Development Environment:**
- **Apache 2.4** with Shopware-optimized configuration
- **MySQL 8** with built-in database
- **Mailpit** for email testing on port 8025
- **Xdebug 3** enabled by default on port 9003
- **Node.js** (version 22 for Shopware 6.7, version 20 for older versions)
- **Shopware CLI** and **Composer 2**
- **Demo data** pre-installed for development
- **All development tools** included

## 🛠️ Development Tools
- **Xdebug 3** - Full debugging support with IDE integration
- **Apache 2.4** - Web server with Shopware-optimized configuration
- **MySQL 8** - Database server with Shopware-tuned settings
- **Mailpit** - Email testing and debugging (modern MailHog alternative)
- **Demo Data** - Pre-installed sample products and categories
- **Shopware CLI** - Official Shopware command-line interface
- **NPM Scripts** - Complete development workflow scripts

### Common Tools (Both Variants)
- **PHP-FPM** - High-performance PHP processor
- **Node.js** - For building admin and storefront assets (22.x for 6.7, 20.x for 6.5/6.6)
- **Composer 2** - Dependency management
- **Supervisor** - Process management

### Slim Variant Optimizations
- Production-ready PHP configuration
- Minimal system dependencies
- Optimized autoloader
- No development overhead
- Perfect for containerized deployments

### Pre-configured for Development
- `APP_ENV=dev` with all development features enabled (full variant)
- `APP_ENV=prod` optimized for production (slim variant)
- Optimized PHP settings (memory limits, execution time)
- Proper file permissions for plugin development
- Database and admin user automatically created (full variant)
- All necessary Shopware dependencies installed
- Template-based installation from official Shopware production template
- Shopware development scripts from core repository
- Shopware CLI project configuration

## 🔧 Usage Examples

### Full Development Environment
```yaml
services:
  shopware:
    image: ghcr.io/weblabels/shopware-docker/shopware-dev:6.7-full
    ports:
      - "80:80"
      - "3306:3306"
      - "8025:8025"  # Mailpit
      - "9003:9003"   # Xdebug
    volumes:
      - "./src:/var/www/html/custom/plugins/MyPlugin"
    environment:
      - XDEBUG_ENABLED=1
```

### Slim Production-like Environment
```yaml
services:
  shopware:
    image: ghcr.io/weblabels/shopware-docker/shopware-dev:6.7-slim
    ports:
      - "9000:9000"  # PHP-FPM only
    volumes:
      - "./src:/var/www/html/custom/plugins/MyPlugin"
    environment:
      - APP_ENV=prod
      - DATABASE_URL=mysql://shopware:shopware@mysql:3306/shopware
    depends_on:
      - mysql

  mysql:
    image: mysql:8.4
    environment:
      MYSQL_ROOT_PASSWORD: root
      MYSQL_DATABASE: shopware
      MYSQL_USER: shopware
      MYSQL_PASSWORD: shopware

  nginx:
    image: nginx:alpine
    ports:
      - "80:80"
    volumes:
      - "./nginx.conf:/etc/nginx/nginx.conf"
    depends_on:
      - shopware
```

### Multiple Plugins Development
```yaml
services:
  shopware:
    image: ghcr.io/weblabels/shopware-docker/shopware-dev:6.7-full
    ports:
      - "80:80"
      - "3306:3306"
    volumes:
      - "./plugins:/var/www/html/custom/plugins"
      - "./themes:/var/www/html/custom/themes"
```

## 🌐 Access Points

### Full Variant
- **🏪 Shopware Frontend:** http://localhost
- **⚙️ Shopware Admin:** http://localhost/admin
- **📧 Mailpit (Email testing):** http://localhost:8025
- **🗄️ Database:** localhost:3306
- **🐛 Xdebug:** Port 9003

### Slim Variant
- **🐘 PHP-FPM:** Port 9000 (requires web server)
- **🐛 Health Check:** Available at `/ping` endpoint

### Default Credentials (Full Variant)
- **Admin Username:** `admin`
- **Admin Password:** `shopware`
- **Database User:** `shopware`
- **Database Password:** `shopware`

## 🛠️ Development Workflow

### NPM Scripts (Full Variant)
The full variant includes all development scripts from the official Shopware repository:

```bash
# Admin development
docker exec <container> npm run admin:build          # Build admin interface
docker exec <container> npm run admin:watch          # Watch admin changes  
docker exec <container> npm run admin:dev            # Development build

# Storefront development  
docker exec <container> npm run storefront:build     # Build storefront
docker exec <container> npm run storefront:watch     # Watch storefront changes
docker exec <container> npm run storefront:dev       # Development build

# Combined workflows
docker exec <container> npm run build:all           # Build everything
docker exec <container> npm run watch               # Watch all changes
```

### Shopware CLI Commands
Pre-installed and configured in both variants:

```bash
# Project management
docker exec <container> shopware-cli project dump-bundles     # Dump bundles
docker exec <container> shopware-cli project admin-build      # Build admin
docker exec <container> shopware-cli project storefront-build # Build storefront

# Extension development
docker exec <container> shopware-cli extension zip            # Create extension zip
docker exec <container> shopware-cli extension validate       # Validate extension
docker exec <container> shopware-cli extension create         # Create new extension

# Development helpers
docker exec <container> shopware-cli project generate-jwt     # Generate JWT keys
```

## 🔧 Environment Variables

| Variable                               | Default                                              | Description                               |
| -------------------------------------- | ---------------------------------------------------- | ----------------------------------------- |
| `APP_URL`                              | `http://localhost`                                   | Base URL for Shopware                    |
| `DATABASE_URL`                         | `mysql://shopware:shopware@localhost:3306/shopware` | Database connection                       |
| `APP_ENV`                              | `dev`                                                | Shopware environment mode                 |
| `XDEBUG_ENABLED`                       | `1`                                                  | Enable/disable Xdebug                    |
| `SHOPWARE_ADMIN_BUILD_ONLY_EXTENSIONS` | `1`                                                  | Only build admin extensions (faster)     |
| `DISABLE_ADMIN_COMPILATION_TYPECHECK`  | `1`                                                  | Disable TypeScript checking (faster)     |
| `PUPPETEER_SKIP_CHROMIUM_DOWNLOAD`     | `1`                                                  | Skip Chromium download for faster startup|

## 🐛 Debugging Setup

### VS Code
Add to your `.vscode/launch.json`:
```json
{
  "name": "Listen for Xdebug",
  "type": "php",
  "request": "launch",
  "port": 9003,
  "pathMappings": {
    "/var/www/html": "${workspaceFolder}"
  }
}
```

### PhpStorm
1. Go to **Settings → PHP → Servers**
2. Add server with:
   - Name: `localhost`
   - Host: `localhost`
   - Port: `80`
   - Debugger: `Xdebug`
   - Path mapping: `<project_root>` → `/var/www/html`

## 🏗️ Building Images

### Modern Build System
This project uses Docker Buildx Bake for efficient multi-platform builds:

```bash
# Build all versions and variants
docker buildx bake

# Build specific version
docker buildx bake shopware-6-7-full
docker buildx bake shopware-6-7-slim

# Build for specific platform
docker buildx bake --set shopware-6-7-full.platform=linux/amd64

# Build and push to registry
docker buildx bake --push
```

### Legacy Build Script
For compatibility, the old build script is still available:

```bash
# Build all versions
./build.sh

# Build specific version
./build.sh 6.7

# Build for specific platform  
./build.sh 6.7 linux/amd64
```

### Build Matrix
The build system automatically generates builds for:
- **Platforms:** `linux/amd64`, `linux/arm64`
- **Variants:** `full` (complete), `slim` (minimal)
- **Versions:** 6.5, 6.6, 6.7 with appropriate PHP versions

## 📁 Project Structure

```
shopware-docker/
├── 6.5/                          # Shopware 6.5 specific files
│   ├── Dockerfile                # Full variant Dockerfile
│   ├── apache-shopware.conf      # Apache configuration
│   ├── start.sh                  # Container startup script
│   ├── supervisord.conf          # Process management
│   └── .env.dev                  # Development environment
├── 6.6/                          # Shopware 6.6 specific files
│   └── [same structure as 6.5]
├── 6.7/                          # Shopware 6.7 specific files  
│   └── [same structure as 6.5]
├── templates/                    # Template files for multi-stage builds
│   ├── Dockerfile.base           # Base template for full variant
│   ├── Dockerfile.slim           # Slim variant template
│   ├── start-slim.sh             # Slim variant startup script
│   └── supervisord-slim.conf     # Slim variant process management
├── scripts/                      # Build automation scripts
│   ├── generate-matrix.mjs       # Version matrix generator
│   └── health-check.sh           # Container health check
├── .github/workflows/            # CI/CD pipelines
│   └── build.yml                 # Automated builds and publishing
├── docker-bake.hcl               # Modern build configuration
├── build.sh                      # Legacy build script
├── setup.sh                      # Development environment setup
├── Makefile                      # Development shortcuts
├── README.md                     # This file
├── Troubleshooting.md            # Problem solving guide
└── BUILD_IMPROVEMENTS.md         # Development notes
```

### File Purposes

**Version Directories (6.5/, 6.6/, 6.7/):**
- Full variant Dockerfiles with complete development environment
- Apache configuration optimized for Shopware
- Startup scripts with service orchestration
- Environment configurations

**Templates Directory:**
- `Dockerfile.base`: Multi-stage template for generating full variant builds
- `Dockerfile.slim`: Production-optimized minimal variant
- Shared configuration files for slim builds

**Scripts Directory:**
- `generate-matrix.mjs`: Generates build matrix for CI/CD
- `health-check.sh`: Container health verification

**Build System:**
- `docker-bake.hcl`: Modern declarative build configuration
- `build.sh`: Legacy shell-based build script for compatibility
- `.github/workflows/`: Automated CI/CD with GitHub Actions

## 🔄 Differences from Dockware

| Feature                 | This Project                   | Dockware             |
| ----------------------- | ------------------------------ | -------------------- |
| **Base System**         | Ubuntu 22.04                   | Ubuntu 18.04/20.04   |
| **Installation Method** | Production template + dev deps | Custom installation  |
| **PHP Versions**        | Latest stable (8.2-8.4)        | Multiple versions    |
| **Shopware Versions**   | Latest stable releases         | Many versions        |
| **Container Size**      | Optimized                      | Larger               |
| **Update Frequency**    | Regular                        | Community-driven     |
| **Development Focus**   | Modern development workflow    | Legacy compatibility |

## 🚀 Performance Tips

### Faster Startup
```yaml
environment:
  - PUPPETEER_SKIP_CHROMIUM_DOWNLOAD=1
  - SHOPWARE_ADMIN_BUILD_ONLY_EXTENSIONS=1
  - DISABLE_ADMIN_COMPILATION_TYPECHECK=1
```

### Persistent Data
```yaml
volumes:
  - mysql_data:/var/lib/mysql
  - shopware_media:/var/www/html/public/media
```

### Development Mode Optimization
The images are pre-configured with:
- Disabled HTTP cache for immediate changes
- Sync message transport for instant processing
- Optimized PHP OPcache for development
- Pre-built assets for faster startup

## 🐳 Docker Best Practices

- Use specific version tags in production
- Mount only necessary directories
- Use `.dockerignore` to exclude unnecessary files
- Consider multi-stage builds for custom images
- Use health checks for reliable deployments

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Test with multiple Shopware versions
5. Submit a pull request

## 📄 License

MIT License - see [LICENSE](LICENSE) for details.

## 🆘 Support

- **Issues:** GitHub Issues
- **Discussions:** GitHub Discussions  
- **Documentation:** This README + inline comments

## 🔄 Version Updates

We regularly update the images with:
- Latest Shopware security releases
- PHP security updates
- Development tool improvements
- Performance optimizations

Subscribe to releases to get notified of updates.

---

**Happy Shopware Development! 🛍️**
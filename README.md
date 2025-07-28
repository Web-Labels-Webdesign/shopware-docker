# Shopware Development Docker Images

A modern alternative to dockware for Shopware 6 development with all the latest versions and development tools pre-configured.

## 🚀 Quick Start

```bash
# Use with docker-compose (recommended)
docker-compose up -d

# Or run directly
docker run -d \
  --name shopware-dev \
  -p 80:80 -p 3306:3306 -p 8025:8025 -p 9003:9003 \
  -v "./src:/var/www/html/custom/plugins/YourPlugin" \
  ghcr.io/your-username/shopware-docker/shopware-dev:latest
```

## 📋 Available Versions

| Shopware Version | PHP Version | Tag                        | Status   |
| ---------------- | ----------- | -------------------------- | -------- |
| 6.7.1.0          | 8.4         | `latest`, `6.7.1.0`, `6.7` | ✅ Active |
| 6.6.10.6         | 8.3         | `6.6.10.6`, `6.6`          | ✅ Active |
| 6.5.8.18         | 8.2         | `6.5.8.18`, `6.5`          | ✅ Active |

## 🛠️ What's Included

### Development Tools
- **Xdebug 3** - Full debugging support with IDE integration
- **Symfony Profiler** - Performance and debugging insights  
- **MailHog** - Email testing and debugging
- **Demo Data** - Pre-installed sample products and categories
- **Hot Reload** - Automatic asset rebuilding during development
- **Shopware CLI** - Official Shopware command-line interface
- **NPM Scripts** - Complete development workflow scripts from Shopware core

### Services
- **Apache 2.4** - Web server with Shopware-optimized configuration
- **MySQL 8** - Database server with Shopware-tuned settings
- **PHP-FPM** - High-performance PHP processor
- **Node.js 22** - For building admin and storefront assets
- **Composer 2** - Dependency management

### Pre-configured for Development
- `APP_ENV=dev` with all development features enabled
- Optimized PHP settings (1GB memory limit, extended execution time)
- Proper file permissions for plugin development
- Database and admin user automatically created
- All Shopware dev dependencies installed
- Shopware development scripts from core repository
- Shopware CLI project configuration

## 🔧 Usage Examples

### Basic Plugin Development
```yaml
services:
  shopware:
    image: ghcr.io/your-username/shopware-docker/shopware-dev:6.7.1.0
    ports:
      - "80:80"
      - "3306:3306"
    volumes:
      - "./src:/var/www/html/custom/plugins/MyPlugin"
    environment:
      - XDEBUG_ENABLED=1
```

### Multiple Plugins
```yaml
services:
  shopware:
    image: ghcr.io/your-username/shopware-docker/shopware-dev:6.7.1.0
    ports:
      - "80:80"
      - "3306:3306"
    volumes:
      - "./plugins:/var/www/html/custom/plugins"
      - "./themes:/var/www/html/custom/themes"
```

### With External Database
```yaml
services:
  shopware:
    image: ghcr.io/your-username/shopware-docker/shopware-dev:6.7.1.0
    ports:
      - "80:80"
    environment:
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
```

## 🌐 Access Points

Once running, you can access:

- **🏪 Shopware Frontend:** http://localhost
- **⚙️ Shopware Admin:** http://localhost/admin
- **📧 MailHog (Email testing):** http://localhost:8025
- **🗄️ Database:** localhost:3306
- **🐛 Xdebug:** Port 9003

### Default Credentials
- **Admin Username:** `admin`
- **Admin Password:** `shopware`
- **Database User:** `shopware`
- **Database Password:** `shopware`

## 🛠️ Development Workflow

### NPM Scripts (from Shopware Core)
The images include all development scripts from the official Shopware repository:

```bash
# Admin development
docker exec <container> npm run admin:build          # Build admin interface
docker exec <container> npm run admin:watch          # Watch admin changes  
docker exec <container> npm run admin:dev            # Development build
docker exec <container> npm run admin:code-mods      # Run code modifications

# Storefront development  
docker exec <container> npm run storefront:build     # Build storefront
docker exec <container> npm run storefront:watch     # Watch storefront changes
docker exec <container> npm run storefront:dev       # Development build

# Combined workflows
docker exec <container> npm run build:all           # Build everything
docker exec <container> npm run watch:admin         # Alias for admin:watch
docker exec <container> npm run watch:storefront    # Alias for storefront:watch
```

### Shopware CLI Commands
Pre-installed and configured Shopware CLI for advanced workflows:

```bash
# Project management
docker exec <container> shopware-cli project dump-bundles     # Dump bundles
docker exec <container> shopware-cli project admin-build      # Build admin
docker exec <container> shopware-cli project storefront-build # Build storefront

# Extension development
docker exec <container> shopware-cli extension zip            # Create extension zip
docker exec <container> shopware-cli extension validate       # Validate extension
docker exec <container> shopware-cli extension create         # Create new extension

# Store operations
docker exec <container> shopware-cli extension upload         # Upload to store
docker exec <container> shopware-cli extension download       # Download from store

# Development helpers
docker exec <container> shopware-cli project generate-jwt     # Generate JWT keys
docker exec <container> shopware-cli project ci              # CI/CD helpers
```

## 🔧 Environment Variables

| Variable                               | Default                                             | Description                               |
| -------------------------------------- | --------------------------------------------------- | ----------------------------------------- |
| `XDEBUG_ENABLED`                       | `1`                                                 | Enable/disable Xdebug                     |
| `APP_URL`                              | `http://localhost`                                  | Base URL for Shopware                     |
| `DATABASE_URL`                         | `mysql://shopware:shopware@localhost:3306/shopware` | Database connection                       |
| `PUPPETEER_SKIP_CHROMIUM_DOWNLOAD`     | `1`                                                 | Skip Chromium download for faster startup |
| `SHOPWARE_ADMIN_BUILD_ONLY_EXTENSIONS` | `1`                                                 | Only build admin extensions (faster)      |
| `DISABLE_ADMIN_COMPILATION_TYPECHECK`  | `1`                                                 | Disable TypeScript checking (faster)      |

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

### Build All Versions
```bash
./build.sh
```

### Build Specific Version
```bash
./build.sh 6.7.1.0
```

### Build for Specific Platform
```bash
./build.sh 6.7.1.0 linux/amd64
```

## 📁 Project Structure

```
shopware-docker/
├── 6.5/
│   └── Dockerfile
├── 6.6/
│   └── Dockerfile  
├── 6.7/
│   └── Dockerfile
├── .github/workflows/
│   └── build.yml
├── apache-shopware.conf
├── .env.dev
├── supervisord.conf
├── start.sh
├── build.sh
├── docker-compose.yml
└── README.md
```

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
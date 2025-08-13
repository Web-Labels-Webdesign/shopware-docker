# Shopware Docker

Enhanced Docker images based on [dockware/dev](https://dockware.io) that eliminate permission issues in development environments while maintaining full compatibility.

[![Build Status](https://github.com/Web-Labels-Webdesign/shopware-docker/actions/workflows/build-and-push.yml/badge.svg)](https://github.com/Web-Labels-Webdesign/shopware-docker/actions/workflows/build-and-push.yml)
[![Docker Pulls](https://img.shields.io/docker/pulls/ghcr.io/web-labels-webdesign/shopware-docker)](https://github.com/Web-Labels-Webdesign/shopware-docker/pkgs/container/shopware-docker)

## 🚀 Key Features

- **Zero-friction permissions on Linux**: Automatic UID/GID mapping eliminates the need for manual `chown` commands
- **Windows compatibility**: Maintains existing Windows Docker Desktop workflows unchanged
- **Drop-in replacement**: Works with existing `dockware/dev` configurations
- **Multi-version support**: Available for multiple Shopware and dockware versions
- **Smart detection**: Automatically detects host environment and configures accordingly

## 🎯 Problem Solved

When using `dockware/dev` on Linux hosts:
- Files created in container (www-data UID 33) become inaccessible on host (user UID 1000+)
- Files created on host require ownership changes for container access
- Constant `chown` commands disrupt development flow

**This image solves these issues automatically** while maintaining 100% compatibility with existing setups.

## 📦 Quick Start

### Replace your existing dockware usage

**Before:**
```yaml
services:
  shopware:
    image: dockware/dev:6.6.10.4
    # ... rest of your configuration
```

**After:**
```yaml
services:
  shopware:
    image: ghcr.io/web-labels-webdesign/shopware-docker:dockware-6.6.10.4
    # ... rest of your configuration unchanged
```

That's it! No other changes required.

## 🏃‍♂️ Complete Example

### Basic Shopware Development Setup

```yaml
# docker-compose.yml
version: '3.8'

services:
  shopware:
    image: ghcr.io/web-labels-webdesign/shopware-docker:dockware-6.6.10.4
    container_name: shopware_dev
    ports:
      - "80:80"
      - "443:443"
      - "3306:3306"
    volumes:
      - ./src:/var/www/html/custom/plugins/YourPlugin
    environment:
      # Shopware Docker specific settings
      - SHOPWARE_DOCKER_AUTO_PERMISSIONS=true
      - SHOPWARE_DOCKER_DEBUG=false
      
      # Standard dockware settings (unchanged)
      - XDEBUG_ENABLED=1
      - COMPOSER_VERSION=2
```

### Plugin Development Setup

```yaml
# docker-compose.yml for plugin development
version: '3.8'

services:
  shopware:
    image: ghcr.io/web-labels-webdesign/shopware-docker:dockware-6.6.10.4
    container_name: my_plugin_dev
    ports:
      - "8080:80"
    volumes:
      # Mount your plugin source
      - ./src:/var/www/html/custom/plugins/MyAwesomePlugin
      # Optional: Mount custom configs
      - ./docker/config:/var/www/html/config/packages/dev
    environment:
      - SHOPWARE_DOCKER_AUTO_PERMISSIONS=true
      - XDEBUG_ENABLED=1
      - PHP_VERSION=8.2
```

### Complete Development Environment

```yaml
# docker-compose.yml with external database
version: '3.8'

services:
  shopware:
    image: ghcr.io/web-labels-webdesign/shopware-docker:dockware-6.6.10.4
    container_name: shopware_full
    ports:
      - "80:80"
      - "443:443"
    volumes:
      - ./custom:/var/www/html/custom
      - ./files:/var/www/html/files
      - ./var/log:/var/www/html/var/log
    environment:
      - SHOPWARE_DOCKER_AUTO_PERMISSIONS=true
      - DATABASE_URL=mysql://shopware:shopware@db:3306/shopware
    depends_on:
      - db
      - redis

  db:
    image: mysql:8.0
    environment:
      MYSQL_ROOT_PASSWORD: root
      MYSQL_DATABASE: shopware
      MYSQL_USER: shopware
      MYSQL_PASSWORD: shopware
    volumes:
      - mysql_data:/var/lib/mysql

  redis:
    image: redis:7-alpine
    volumes:
      - redis_data:/data

volumes:
  mysql_data:
  redis_data:
```

## 🔧 Configuration

### Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `SHOPWARE_DOCKER_AUTO_PERMISSIONS` | `true` | Enable automatic permission handling |
| `SHOPWARE_DOCKER_HOST_UID` | `auto` | Host user ID (auto-detected or manual) |
| `SHOPWARE_DOCKER_HOST_GID` | `auto` | Host group ID (auto-detected or manual) |
| `SHOPWARE_DOCKER_DEBUG` | `false` | Enable debug logging |

### Manual UID/GID Override

If auto-detection doesn't work for your setup:

```yaml
services:
  shopware:
    image: ghcr.io/web-labels-webdesign/shopware-docker:dockware-6.6.10.4
    environment:
      - SHOPWARE_DOCKER_HOST_UID=1000
      - SHOPWARE_DOCKER_HOST_GID=1000
```

### Disable Auto-Permissions

For Windows/macOS or if you prefer manual control:

```yaml
services:
  shopware:
    image: ghcr.io/web-labels-webdesign/shopware-docker:dockware-6.6.10.4
    environment:
      - SHOPWARE_DOCKER_AUTO_PERMISSIONS=false
```

## 🏷️ Available Tags

### Current Versions (Phase 2+)

| Tag | Base Dockware | Shopware | PHP | Node |
|-----|---------------|----------|-----|------|
| `dockware-6.6.10.4` | 6.6.10.4 | 6.6.10.4 | 8.1, 8.2 | 18, 20 |
| `dockware-6.5.8.10` | 6.5.8.10 | 6.5.8.10 | 8.1, 8.2 | 18, 20 |
| `dockware-6.4.20.2` | 6.4.20.2 | 6.4.20.2 | 8.0, 8.1 | 16, 18 |

### Generic Tags

- `latest` - Most recent stable build (currently dockware-6.6.10.4)
- `main` - Latest build from main branch

### Platform Support

All images support:
- `linux/amd64`
- `linux/arm64` (Apple Silicon, ARM servers)

## 🔍 How It Works

### Linux Hosts
1. Container detects it's running on Linux
2. Examines mounted volume ownership to determine host UID/GID
3. Updates container's `www-data` user to match host user
4. Files created in container are automatically owned by your host user

### Windows/macOS Hosts
1. Container detects Docker Desktop environment
2. Skips UID/GID mapping (Docker Desktop handles this automatically)
3. Maintains standard dockware behavior

### Debug Mode
Enable debug logging to see what's happening:

```bash
docker run -e SHOPWARE_DOCKER_DEBUG=true \
  ghcr.io/web-labels-webdesign/shopware-docker:dockware-6.6.10.4
```

## 🧪 Testing

### Local Testing
```bash
# Build locally
docker build -t shopware-docker-test .

# Run smoke test
./.github/scripts/smoke-test.sh shopware-docker-test

# Manual testing
docker run -it --rm -v $(pwd):/var/www/html/test \
  -e SHOPWARE_DOCKER_DEBUG=true \
  shopware-docker-test bash
```

### Continuous Integration
The project includes comprehensive CI/CD with:
- Automated builds for multiple dockware versions
- Cross-platform builds (amd64/arm64)
- Smoke tests for each image
- Bi-weekly checks for new dockware releases

## 📋 Migration Guide

### From dockware/dev

1. **Update your docker-compose.yml:**
   ```diff
   services:
     shopware:
   -   image: dockware/dev:6.6.10.4
   +   image: ghcr.io/web-labels-webdesign/shopware-docker:dockware-6.6.10.4
   ```

2. **Remove manual permission fixes:**
   ```diff
   # You can remove these commands from your workflow:
   - sudo chown -R $USER:$USER ./custom/
   - docker exec shopware chown -R www-data:www-data /var/www/html/
   ```

3. **Optional: Add configuration:**
   ```yaml
   environment:
     - SHOPWARE_DOCKER_DEBUG=true  # Optional: for debugging
   ```

### Rollback Plan

If you encounter issues, simply revert to the original dockware image:
```yaml
image: dockware/dev:6.6.10.4  # Back to original
```

## ⚡ Performance

- **Container startup**: < 30 seconds additional overhead
- **Image size**: < 500MB increase compared to base dockware
- **Runtime performance**: No measurable impact on Shopware performance

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Add tests if applicable
5. Submit a pull request

### Development Setup
```bash
git clone https://github.com/Web-Labels-Webdesign/shopware-docker.git
cd shopware-docker

# Test your changes
docker build -t shopware-docker-dev .
./.github/scripts/smoke-test.sh shopware-docker-dev
```

## 📚 Advanced Usage

### Custom Entrypoint Scripts

If you need to add additional initialization logic:

```dockerfile
FROM ghcr.io/web-labels-webdesign/shopware-docker:dockware-6.6.10.4

COPY my-init-script.sh /usr/local/bin/
RUN chmod +x /usr/local/bin/my-init-script.sh

# The smart-entrypoint will still run first
ENTRYPOINT ["/usr/local/bin/smart-entrypoint.sh", "/usr/local/bin/my-init-script.sh"]
```

### Multi-Stage Development

```yaml
# Development
services:
  shopware-dev:
    image: ghcr.io/web-labels-webdesign/shopware-docker:dockware-6.6.10.4
    environment:
      - SHOPWARE_DOCKER_DEBUG=true
      - XDEBUG_ENABLED=1

# Testing  
services:
  shopware-test:
    image: ghcr.io/web-labels-webdesign/shopware-docker:dockware-6.6.10.4
    environment:
      - SHOPWARE_DOCKER_AUTO_PERMISSIONS=false
      - APP_ENV=test
```

## 🆘 Troubleshooting

### Permission Issues Still Occurring

1. **Check debug output:**
   ```bash
   docker logs your-container-name
   ```

2. **Verify auto-detection:**
   ```bash
   docker exec your-container-name id www-data
   stat your-mounted-directory
   ```

3. **Manual override:**
   ```yaml
   environment:
     - SHOPWARE_DOCKER_HOST_UID=1000
     - SHOPWARE_DOCKER_HOST_GID=1000
   ```

### Container Won't Start

1. **Check base image availability:**
   ```bash
   docker pull dockware/dev:6.6.10.4
   ```

2. **Run with debug:**
   ```bash
   docker run -e SHOPWARE_DOCKER_DEBUG=true your-image
   ```

3. **Check entrypoint:**
   ```bash
   docker run --entrypoint=/bin/bash -it your-image
   ```

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🙏 Acknowledgments

- [dockware](https://dockware.io) for providing the excellent base images
- [Shopware](https://shopware.com) for the amazing e-commerce platform
- The Docker and PHP communities for continuous innovation

## 📞 Support

- 🐛 [Report Issues](https://github.com/Web-Labels-Webdesign/shopware-docker/issues)
- 💬 [Discussions](https://github.com/Web-Labels-Webdesign/shopware-docker/discussions)
- 📧 [Contact Web Labels Webdesign](mailto:info@web-labels.de)

---

Made with ❤️ by [Web Labels Webdesign](https://www.web-labels.de)
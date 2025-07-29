# Shopware Docker Development Images

This repository provides Docker images for Shopware 6 development with support for versions 6.5, 6.6, and 6.7. Each image includes all necessary components for Shopware development including MySQL, Redis, and the Shopware CLI.

## Features

- 🚀 **Multi-version support**: Shopware 6.5, 6.6, and 6.7
- 🐘 **PHP versions**: Optimized PHP versions for each Shopware release (8.1, 8.2, 8.3)
- 🗄️ **MySQL**: Pre-configured MySQL database
- 🔴 **Redis**: Redis server for caching
- 🛠️ **Shopware CLI**: Latest Shopware CLI tools
- 🐛 **Xdebug**: Configurable Xdebug for debugging
- 🔄 **Auto-builds**: Weekly builds to get latest Shopware updates
- 🌐 **Multi-platform**: Supports AMD64 and ARM64 architectures
- ⚡ **Fast startup**: Shopware pre-installed during build for faster container startup
- 🔧 **Development optimized**: Pre-configured for plugin development

## Quick Start

### Using Pre-built Images

The easiest way to get started is using our pre-built images from GitHub Container Registry:

```yaml
version: '3.8'

services:
  shopware:
    image: ghcr.io/web-labels-webdesign/shopware-docker/shopware-dev:6.7
    container_name: WebLa_SplitComission
    ports:
      - "80"
      - "3306"
    volumes:
      - "./src:/var/www/html/custom/plugins/WebLa_SplitComission"
    networks:
      - web
    environment:
      - XDEBUG_ENABLED=1
      - PUPPETEER_SKIP_CHROMIUM_DOWNLOAD=1
      - SHOPWARE_ADMIN_BUILD_ONLY_EXTENSIONS=1
      - DISABLE_ADMIN_COMPILATION_TYPECHECK=1

networks:
  web:
    name: web
    driver: bridge
    external: true
```

### Available Images

- `ghcr.io/web-labels-webdesign/shopware-docker/shopware-dev:6.5` - Shopware 6.5 with PHP 8.1
- `ghcr.io/web-labels-webdesign/shopware-docker/shopware-dev:6.6` - Shopware 6.6 with PHP 8.2
- `ghcr.io/web-labels-webdesign/shopware-docker/shopware-dev:6.7` - Shopware 6.7 with PHP 8.3

## Local Development

### Building Images Locally

1. Clone this repository:
```bash
git clone https://github.com/Web-Labels-Webdesign/shopware-docker.git
cd shopware-docker
```

2. Build a specific version using the build script:

**Linux/macOS:**
```bash
chmod +x build.sh
./build.sh 6.7  # or 6.5, 6.6
```

**Windows (PowerShell):**
```powershell
.\build.ps1 -Version 6.7  # or 6.5, 6.6
```

**Manual build:**
```bash
docker build --build-arg SHOPWARE_VERSION=6.7 --build-arg PHP_VERSION=8.3 -t shopware-dev:6.7 .
```

3. Or use Docker Compose to build all versions:
```bash
docker-compose up -d
```

### Development Workflow

1. **Start a Shopware instance**:
```bash
docker run -d --name shopware-dev \
  -p 8080:80 \
  -p 3306:3306 \
  -v "./your-plugin:/var/www/html/custom/plugins/YourPlugin" \
  -e XDEBUG_ENABLED=1 \
  ghcr.io/web-labels-webdesign/shopware-docker/shopware-dev:6.7
```

2. **Access Shopware**:
   - Frontend: http://localhost:8080
   - Admin: http://localhost:8080/admin
   - Default credentials: admin / shopware

3. **Access MySQL**:
   - Host: localhost:3306
   - Database: shopware
   - Username: shopware
   - Password: shopware

## Environment Variables

| Variable                               | Description                          | Default |
| -------------------------------------- | ------------------------------------ | ------- |
| `XDEBUG_ENABLED`                       | Enable/disable Xdebug                | `0`     |
| `PUPPETEER_SKIP_CHROMIUM_DOWNLOAD`     | Skip Chromium download for Puppeteer | `0`     |
| `SHOPWARE_ADMIN_BUILD_ONLY_EXTENSIONS` | Build only extensions in admin       | `0`     |
| `DISABLE_ADMIN_COMPILATION_TYPECHECK`  | Disable TypeScript checking          | `0`     |

## Volumes

- `/var/www/html/custom/plugins/[PluginName]` - Mount your plugin directory here
- `/var/www/html/files` - Shopware media files
- `/var/www/html/var/log` - Shopware logs

## Ports

- `80` - Apache web server
- `3306` - MySQL database
- `6379` - Redis server
- `9003` - Xdebug (when enabled)

## Development Tools

Each image includes:

- **Shopware CLI**: Available as `shopware-cli` command
- **Composer**: Latest version
- **Node.js**: Version 18 LTS
- **npm**: Latest version
- **Git**: For version control
- **Vim/Nano**: Text editors
- **MySQL Client**: For database operations
- **Redis CLI**: For Redis operations

## Debugging with Xdebug

1. Enable Xdebug by setting `XDEBUG_ENABLED=1`
2. Configure your IDE to listen on port 9003
3. Set path mappings in your IDE:
   - Local path: `./src`
   - Remote path: `/var/www/html/custom/plugins/YourPlugin`

### VS Code Configuration

Add to your `.vscode/launch.json`:

```json
{
  "version": "0.2.0",
  "configurations": [
    {
      "name": "Listen for Xdebug",
      "type": "php",
      "request": "launch",
      "port": 9003,
      "pathMappings": {
        "/var/www/html/custom/plugins/YourPlugin": "${workspaceFolder}/src"
      }
    }
  ]
}
```

## Database Access

The MySQL database is automatically configured with:
- Database: `shopware`
- Username: `shopware`
- Password: `shopware`
- Root password: `root`

You can connect using any MySQL client or use the built-in MySQL CLI:

```bash
docker exec -it container_name mysql -u shopware -p shopware
```

## Plugin Development

1. Mount your plugin directory to `/var/www/html/custom/plugins/YourPlugin`
2. The plugin will be automatically detected by Shopware
3. Use the Shopware CLI to manage plugins:

```bash
# List plugins
docker exec container_name shopware-cli plugin:list

# Install plugin
docker exec container_name shopware-cli plugin:install YourPlugin

# Activate plugin
docker exec container_name shopware-cli plugin:activate YourPlugin
```

## Performance Optimization

For better performance during development:

1. **Disable Xdebug** when not debugging: `XDEBUG_ENABLED=0`
2. **Skip admin builds**: `SHOPWARE_ADMIN_BUILD_ONLY_EXTENSIONS=1`
3. **Disable TypeScript checking**: `DISABLE_ADMIN_COMPILATION_TYPECHECK=1`
4. **Use host networking** for better performance (Linux only)

## Troubleshooting

### Container won't start
- Check if ports 80, 3306, or 6379 are already in use
- Verify Docker has enough memory allocated (recommend 4GB+)

### Shopware is slow
- Increase Docker memory allocation
- Disable Xdebug when not debugging
- Use environment variables to skip unnecessary builds

### Database connection issues
- Wait for MySQL to fully initialize (can take 30-60 seconds)
- Check if port 3306 is available
- Verify database credentials

### Plugin not detected
- Ensure plugin directory is correctly mounted
- Check file permissions
- Restart the container after mounting

## Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Test with all Shopware versions
5. Submit a pull request

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Support

For issues and questions:
- Create an issue in this repository
- Contact Web Labels Webdesign
- Check Shopware documentation: https://docs.shopware.com

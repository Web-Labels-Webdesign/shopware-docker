# 🔧 Troubleshooting Guide

## Common Issues and Solutions

### Container Won't Start

**Problem:** Container exits immediately or shows error messages

**Solutions:**
```bash
# Check container logs
docker logs <container-name>

# Check if ports are already in use
sudo netstat -tlnp | grep :80
sudo netstat -tlnp | grep :3306

# Try running with different ports
docker run -p 8080:80 -p 3307:3306 your-registry/shopware-dev:latest
```

### Database Connection Issues

**Problem:** "Connection refused" or "Access denied" errors

**Solutions:**
```bash
# Wait for MySQL to be ready (takes 30-60 seconds)
docker exec -it <container-name> mysqladmin ping -h localhost

# Check MySQL status
docker exec -it <container-name> service mysql status

# Reset database
docker exec -it <container-name> mysql -e "DROP DATABASE IF EXISTS shopware; CREATE DATABASE shopware;"
docker exec -it <container-name> bin/console system:install --create-database --basic-setup --force
```

### Xdebug Not Working

**Problem:** IDE doesn't receive debug connections

**Solutions:**
```bash
# Check if Xdebug is enabled
docker exec -it <container-name> php -m | grep xdebug

# Verify Xdebug configuration
docker exec -it <container-name> php -i | grep xdebug

# Test Xdebug connection
docker exec -it <container-name> bash -c 'echo "<?php xdebug_info();" | php'
```

**IDE Configuration:**
- **Host:** `localhost` or `127.0.0.1`
- **Port:** `9003`
- **Path mapping:** `{project-root}` → `/var/www/html`

### Admin Won't Load

**Problem:** Admin panel shows errors or won't load

**Solutions:**
```bash
# Rebuild admin
docker exec -it <container-name> bin/console bundle:dump
docker exec -it <container-name> bin/console asset:install

# Clear cache
docker exec -it <container-name> bin/console cache:clear

# Check admin build
docker exec -it <container-name> ./bin/build-administration.sh
```

### Plugin Development Issues

**Problem:** Plugin not recognized or changes not reflected

**Solutions:**
```bash
# Refresh plugin list
docker exec -it <container-name> bin/console plugin:refresh

# Install/activate plugin
docker exec -it <container-name> bin/console plugin:install --activate YourPlugin

# Clear cache after changes
docker exec -it <container-name> bin/console cache:clear
```

### Performance Issues

**Problem:** Slow loading times or high memory usage

**Solutions:**
```bash
# Increase container resources in Docker Desktop
# Or use these optimizations:

# Disable Xdebug when not debugging
docker run -e XDEBUG_ENABLED=0 your-registry/shopware-dev:latest

# Use production-like settings
docker run -e APP_ENV=prod your-registry/shopware-dev:latest

# Enable OPcache optimization
docker exec -it <container-name> php -i | grep opcache
```

### File Permission Issues

**Problem:** Can't write files or permission denied errors

**Solutions:**
```bash
# Fix file permissions
docker exec -it <container-name> chown -R www-data:www-data /var/www/html
docker exec -it <container-name> chmod -R 755 /var/www/html

# For specific directories
docker exec -it <container-name> chmod -R 777 /var/www/html/var
docker exec -it <container-name> chmod -R 777 /var/www/html/public/media
```

### Memory Errors

**Problem:** "Allowed memory size exhausted" errors

**Solutions:**
```bash
# Increase PHP memory limit
docker exec -it <container-name> sed -i 's/memory_limit = .*/memory_limit = 2G/' /etc/php/8.4/fpm/php.ini
docker exec -it <container-name> service php8.4-fpm restart

# Or set via environment
docker run -e PHP_MEMORY_LIMIT=2G your-registry/shopware-dev:latest
```

## 🐛 Debug Commands

### System Information
```bash
# Check PHP version and modules
docker exec -it <container-name> php -v
docker exec -it <container-name> php -m

# Check Shopware version
docker exec -it <container-name> bin/console --version

# Check database connection
docker exec -it <container-name> bin/console dbal:run-sql "SELECT VERSION()"

# Check system requirements
docker exec -it <container-name> bin/console system:check
```

### Service Status
```bash
# Check all services
docker exec -it <container-name> supervisorctl status

# Restart specific service
docker exec -it <container-name> supervisorctl restart apache2
docker exec -it <container-name> supervisorctl restart mysql
docker exec -it <container-name> supervisorctl restart php-fpm
```

### Log Analysis
```bash
# Application logs
docker exec -it <container-name> tail -f /var/www/html/var/log/dev.log

# Apache logs
docker exec -it <container-name> tail -f /var/log/apache2/error.log
docker exec -it <container-name> tail -f /var/log/apache2/access.log

# MySQL logs
docker exec -it <container-name> tail -f /var/log/mysql/error.log

# PHP-FPM logs
docker exec -it <container-name> tail -f /var/log/php8.4-fpm.log
```

## 🚨 Emergency Fixes

### Complete Reset
```bash
# Stop and remove container
docker stop <container-name>
docker rm <container-name>

# Remove volumes (CAUTION: This deletes all data!)
docker volume rm $(docker volume ls -q | grep shopware)

# Start fresh
docker-compose up -d
```

### Manual Shopware Installation
```bash
# Enter container
docker exec -it <container-name> bash

# Navigate to Shopware directory
cd /var/www/html

# Force reinstall
bin/console system:install --create-database --basic-setup --force

# Install demo data
bin/console framework:demodata

# Create admin user
bin/console user:create admin --admin --email="admin@example.com" --firstName="Admin" --lastName="User" --password="shopware"
```

### Database Recovery
```bash
# Backup current database
docker exec <container-name> mysqldump shopware > backup.sql

# Restore from backup
docker exec -i <container-name> mysql shopware < backup.sql

# Or start with clean database
docker exec -it <container-name> mysql -e "DROP DATABASE shopware; CREATE DATABASE shopware;"
docker exec -it <container-name> bin/console system:install --create-database --basic-setup --force
```

## 📞 Getting Help

### Container Inspection
```bash
# Get detailed container info
docker inspect <container-name>

# Check resource usage
docker stats <container-name>

# Access container shell
docker exec -it <container-name> bash

# Export container for analysis
docker export <container-name> > container-export.tar
```

### Report Issues
When reporting issues, please include:

1. **Environment Information:**
   ```bash
   docker version
   docker-compose --version
   uname -a
   ```

2. **Container Logs:**
   ```bash
   docker logs <container-name> > container.log
   ```

3. **Configuration:**
   - Your `docker-compose.yml`
   - Environment variables used
   - Volume mounts

4. **Error Messages:**
   - Full error messages from logs
   - Screenshots if applicable

### Community Support
- **GitHub Issues:** For bugs and feature requests
- **GitHub Discussions:** For questions and community help
- **Discord/Slack:** Real-time community support (if available)

## 💡 Pro Tips

### Development Workflow
```bash
# Watch logs in real-time
docker-compose logs -f shopware

# Quick cache clear
docker exec <container-name> bin/console ca:cl

# Quick plugin refresh
docker exec <container-name> bin/console pl:ref

# Database backup before major changes
docker exec <container-name> mysqldump shopware > backup-$(date +%Y%m%d).sql
```

### Performance Monitoring
```bash
# Monitor resource usage
docker stats --no-stream

# Check PHP processes
docker exec <container-name> ps aux | grep php

# Monitor MySQL processes
docker exec <container-name> mysql -e "SHOW PROCESSLIST;"
```

Remember: Most issues can be resolved by checking logs first and ensuring all services are running properly! 🔍
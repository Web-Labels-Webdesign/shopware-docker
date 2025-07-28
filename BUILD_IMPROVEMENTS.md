# Build Process Improvements

This document outlines the comprehensive improvements made to the Shopware Docker build system, inspired by modern containerization best practices and the shopwareLabs/devcontainer approach.

## 🚀 Major Improvements

### 1. **Docker Bake Configuration** (`docker-bake.hcl`)
- **Replaced**: Shell-based `build.sh` script
- **Benefits**: 
  - Multi-platform builds with proper caching
  - Modular target definitions with inheritance
  - Better dependency management
  - Parallel builds and improved performance

```bash
# Build all variants
docker buildx bake --file docker-bake.hcl all

# Build specific variants
docker buildx bake --file docker-bake.hcl all-full
docker buildx bake --file docker-bake.hcl shopware-6-7-full
```

### 2. **Dynamic Version Matrix System** (`scripts/generate-matrix.mjs`)
- **Replaced**: Hardcoded version arrays
- **Features**:
  - Fetches live Shopware releases from GitHub API
  - Automatically determines PHP compatibility
  - Filters out pre-release versions
  - Generates matrices for both GitHub Actions and Docker Bake

```bash
# Generate build matrix
node scripts/generate-matrix.mjs
```

### 3. **Modern Makefile** (`Makefile`)
- **Inspired by**: shopwareLabs/devcontainer
- **Features**:
  - Color-coded output for better UX  
  - Comprehensive build targets
  - Development workflow integration
  - Automatic build context preparation

```bash
# Common operations
make help          # Show available commands
make build         # Build all images
make build-67      # Build specific version
make test          # Run image tests
make setup         # Interactive project setup
```

### 4. **Multi-Stage Dockerfiles with Security**
- **Base Template**: `templates/Dockerfile.base`
- **Slim Variant**: `templates/Dockerfile.slim`
- **Improvements**:
  - Multi-stage builds for smaller images
  - Non-root user execution
  - Security-hardened base images
  - Optimized layer caching
  - Variant-specific optimizations

### 5. **Container Variants**

#### Full Variant
- Complete development environment
- Includes: Apache, MySQL, MailHog, Xdebug
- Ports: 80, 443, 3306, 8025, 9003
- Best for: Local development

#### Slim Variant  
- Minimal PHP-FPM only setup
- Production-optimized
- Ports: 9000 (PHP-FPM)
- Best for: CI/CD, production deployments

### 6. **Enhanced GitHub Actions Workflow**
- **Dynamic matrix generation** from live data
- **Multi-variant support** (full/slim)
- **Advanced caching strategies**:
  - GitHub Actions cache
  - Registry-based cache
  - Scoped caching per variant
- **Comprehensive testing** for both variants
- **Security scanning** with Trivy

### 7. **Comprehensive Caching Strategy**
- **Build-time caching**:
  - APT package cache
  - Composer dependency cache  
  - npm package cache
  - Docker layer cache
- **Runtime caching**:
  - Persistent volumes for data
  - Optimized PHP opcache settings
  - APCu memory cache

### 8. **Health Checks and Monitoring**
- **Enhanced health check script**: `scripts/health-check.sh`
- **Variant-specific checks**:
  - Full: Shopware API, Admin, MailHog
  - Slim: PHP-FPM ping, custom health endpoint
- **Retry logic** with configurable timeouts
- **Comprehensive logging**

### 9. **Modern Setup Script** (Enhanced `setup.sh`)
- **Variant support** (full/slim)
- **Improved project templates**
- **Better error handling**
- **Interactive configuration**

## 📊 Performance Improvements

### Build Time Optimizations
- **Multi-stage builds**: Smaller final images
- **Layer caching**: Faster subsequent builds  
- **Parallel builds**: Multiple architectures simultaneously
- **Scoped caching**: Separate cache per variant

### Runtime Optimizations
- **PHP optimizations**: OPcache, APCu tuning
- **MySQL tuning**: Optimized for Shopware workloads
- **Asset optimization**: Production-ready static assets
- **Non-root execution**: Enhanced security

## 🔧 Usage Examples

### Build Operations
```bash
# Build all variants
make build

# Build specific version and variant
make build-67
docker buildx bake shopware-6-7-slim

# Push to registry
make push
docker buildx bake --push all
```

### Development Workflow
```bash
# Setup new project
make setup
# or
./setup.sh my-project 6.7.1.0 full

# Start development
make dev
# or  
docker-compose up -d

# Monitor logs
make logs
# or
docker-compose logs -f shopware
```

### Testing and Validation
```bash
# Run health checks
scripts/health-check.sh

# Test specific variant
make test

# Security scan
# (Automated in CI/CD)
```

## 🏗️ Architecture Comparison

### Before (Original)
```
build.sh → Dockerfile → Single Image
         ↓
    Static Versions
         ↓
    Basic GitHub Actions
```

### After (Improved)
```
Makefile → docker-bake.hcl → Multiple Variants
    ↑              ↓              ↓
generate-matrix → Full Image    Slim Image
    ↑              ↓              ↓  
Live Data → Enhanced Testing → Security Scan
```

## 📁 File Structure

```
shopware-docker/
├── docker-bake.hcl              # Modern build configuration
├── Makefile                     # Developer-friendly commands
├── scripts/
│   ├── generate-matrix.mjs      # Dynamic version matrix
│   └── health-check.sh          # Enhanced health checks
├── templates/
│   ├── Dockerfile.base          # Multi-stage full variant
│   ├── Dockerfile.slim          # Optimized slim variant
│   ├── supervisord-slim.conf    # Slim supervisor config
│   └── start-slim.sh           # Slim startup script
├── .github/workflows/
│   └── build.yml               # Enhanced CI/CD workflow
└── [existing version directories]
```

## 🎯 Migration Guide

### For Developers
```bash
# Old way
./build.sh 6.7.1.0

# New way  
make build-67
# or
docker buildx bake shopware-6-7-full
```

### For CI/CD
The GitHub Actions workflow now automatically:
1. Generates dynamic build matrix
2. Builds both full and slim variants
3. Tests each variant appropriately
4. Runs security scans
5. Pushes to registry with proper tags

### For Projects
```bash
# Old setup
./setup.sh my-project 6.7.1.0

# New setup (with variants)
./setup.sh my-project 6.7.1.0 full
./setup.sh my-project 6.7.1.0 slim
```

## 🔍 Benefits Summary

1. **Developer Experience**: Modern tooling with better feedback
2. **Build Performance**: Faster builds with intelligent caching
3. **Security**: Multi-stage builds, non-root execution, vulnerability scanning
4. **Flexibility**: Multiple variants for different use cases
5. **Maintainability**: Automated version management, better structure
6. **CI/CD Integration**: GitHub Actions optimized for containerization
7. **Production Ready**: Optimized slim variants for deployment

## 🚀 Next Steps

1. **Test the new build system**: `make build`
2. **Try project setup**: `make setup`
3. **Explore variants**: Compare full vs slim for your use case
4. **Update CI/CD**: The enhanced workflow handles everything automatically
5. **Monitor performance**: New caching should significantly improve build times

The improvements maintain backward compatibility while providing modern, efficient, and secure containerization practices inspired by industry best practices.
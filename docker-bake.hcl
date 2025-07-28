# Shopware Docker Bake Configuration
# Modern replacement for build.sh using Docker Buildx Bake

variable "REGISTRY" {
  default = "ghcr.io"
}

variable "NAMESPACE" {
  default = "weblabels/shopware-docker"
}

variable "IMAGE_NAME" {
  default = "shopware-dev"
}

variable "PLATFORMS" {
  default = ["linux/amd64", "linux/arm64"]
}

# Version matrix with PHP requirements
variable "SHOPWARE_VERSIONS" {
  default = {
    "6.5.8.18" = "8.2"
    "6.6.10.6" = "8.3"
    "6.7.1.0"  = "8.4"
  }
}

# Common build arguments
variable "BUILD_ARGS" {
  default = {
    BUILDKIT_INLINE_CACHE = "1"
  }
}

# Common labels
function "common_labels" {
  params = [version, php_version]
  result = {
    "org.opencontainers.image.title" = "Shopware ${version} Development"
    "org.opencontainers.image.description" = "Shopware ${version} development environment with PHP ${php_version}"
    "org.opencontainers.image.vendor" = "weblabels"
    "org.opencontainers.image.source" = "https://github.com/weblabels/shopware-docker"
    "org.opencontainers.image.licenses" = "MIT"
    "shopware.version" = version
    "php.version" = php_version
  }
}

# Common cache configuration
function "cache_config" {
  params = []
  result = {
    "cache-from" = ["type=gha"]
    "cache-to" = ["type=gha,mode=max"]
  }
}

# Base target for common configuration
target "_common" {
  platforms = PLATFORMS
  labels = {}
  args = BUILD_ARGS
  cache-from = cache_config().cache-from
  cache-to = cache_config().cache-to
}

# Shopware 6.5 Full Development Environment
target "shopware-6-5-full" {
  inherits = ["_common"]
  context = "./build/6.5.8.18"
  dockerfile = "Dockerfile"
  
  args = {
    SHOPWARE_VERSION = "6.5.8.18"
    PHP_VERSION = "8.2"
    VARIANT = "full"
  }
  
  tags = [
    "${REGISTRY}/${NAMESPACE}/${IMAGE_NAME}:6.5.8.18",
    "${REGISTRY}/${NAMESPACE}/${IMAGE_NAME}:6.5",
  ]
  
  labels = common_labels("6.5.8.18", "8.2")
}

# Shopware 6.5 Slim Development Environment  
target "shopware-6-5-slim" {
  inherits = ["_common"]
  context = "./build/6.5.8.18"
  dockerfile = "Dockerfile.slim"
  
  args = {
    SHOPWARE_VERSION = "6.5.8.18"
    PHP_VERSION = "8.2"
    VARIANT = "slim"
  }
  
  tags = [
    "${REGISTRY}/${NAMESPACE}/${IMAGE_NAME}:6.5.8.18-slim",
    "${REGISTRY}/${NAMESPACE}/${IMAGE_NAME}:6.5-slim",
  ]
  
  labels = common_labels("6.5.8.18", "8.2")
}

# Shopware 6.6 Full Development Environment
target "shopware-6-6-full" {
  inherits = ["_common"]
  context = "./build/6.6.10.6"
  dockerfile = "Dockerfile"
  
  args = {
    SHOPWARE_VERSION = "6.6.10.6"
    PHP_VERSION = "8.3"
    VARIANT = "full"
  }
  
  tags = [
    "${REGISTRY}/${NAMESPACE}/${IMAGE_NAME}:6.6.10.6",
    "${REGISTRY}/${NAMESPACE}/${IMAGE_NAME}:6.6",
  ]
  
  labels = common_labels("6.6.10.6", "8.3")
}

# Shopware 6.6 Slim Development Environment
target "shopware-6-6-slim" {
  inherits = ["_common"]
  context = "./build/6.6.10.6"
  dockerfile = "Dockerfile.slim"
  
  args = {
    SHOPWARE_VERSION = "6.6.10.6"
    PHP_VERSION = "8.3"
    VARIANT = "slim"
  }
  
  tags = [
    "${REGISTRY}/${NAMESPACE}/${IMAGE_NAME}:6.6.10.6-slim",
    "${REGISTRY}/${NAMESPACE}/${IMAGE_NAME}:6.6-slim",
  ]
  
  labels = common_labels("6.6.10.6", "8.3")
}

# Shopware 6.7 Full Development Environment (Latest)
target "shopware-6-7-full" {
  inherits = ["_common"]
  context = "./build/6.7.1.0"
  dockerfile = "Dockerfile"
  
  args = {
    SHOPWARE_VERSION = "6.7.1.0"
    PHP_VERSION = "8.4"
    VARIANT = "full"
  }
  
  tags = [
    "${REGISTRY}/${NAMESPACE}/${IMAGE_NAME}:6.7.1.0",
    "${REGISTRY}/${NAMESPACE}/${IMAGE_NAME}:6.7",
    "${REGISTRY}/${NAMESPACE}/${IMAGE_NAME}:latest",
  ]
  
  labels = common_labels("6.7.1.0", "8.4")
}

# Shopware 6.7 Slim Development Environment
target "shopware-6-7-slim" {
  inherits = ["_common"]
  context = "./build/6.7.1.0"
  dockerfile = "Dockerfile.slim"
  
  args = {
    SHOPWARE_VERSION = "6.7.1.0"
    PHP_VERSION = "8.4"
    VARIANT = "slim"
  }
  
  tags = [
    "${REGISTRY}/${NAMESPACE}/${IMAGE_NAME}:6.7.1.0-slim",
    "${REGISTRY}/${NAMESPACE}/${IMAGE_NAME}:6.7-slim",
    "${REGISTRY}/${NAMESPACE}/${IMAGE_NAME}:latest-slim",
  ]
  
  labels = common_labels("6.7.1.0", "8.4")
}

# Group targets for convenience
group "all-full" {
  targets = [
    "shopware-6-5-full",
    "shopware-6-6-full", 
    "shopware-6-7-full"
  ]
}

group "all-slim" {
  targets = [
    "shopware-6-5-slim",
    "shopware-6-6-slim",
    "shopware-6-7-slim"
  ]
}

group "all" {
  targets = [
    "shopware-6-5-full",
    "shopware-6-5-slim",
    "shopware-6-6-full",
    "shopware-6-6-slim", 
    "shopware-6-7-full",
    "shopware-6-7-slim"
  ]
}

group "latest" {
  targets = [
    "shopware-6-7-full",
    "shopware-6-7-slim"
  ]
}
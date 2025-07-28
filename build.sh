#!/bin/bash
# Build script for Shopware Development Images
# Usage: ./build.sh [version] [platform]

set -e

# Configuration - Updated for GitHub Container Registry
REGISTRY="ghcr.io/${GITHUB_REPOSITORY:-$(git config --get remote.origin.url | sed 's|.*github.com[:/]||' | sed 's|\.git$||')}/shopware-dev"
IMAGE_NAME="shopware-dev"
PLATFORMS="linux/amd64,linux/arm64"

# Shopware versions with their PHP requirements
declare -A VERSIONS=(
    ["6.5.8.18"]="8.2"
    ["6.6.10.6"]="8.3"
    ["6.7.1.0"]="8.4"
)

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

print_help() {
    echo "Shopware Development Image Builder"
    echo "================================="
    echo ""
    echo "Usage: $0 [version] [platform]"
    echo ""
    echo "Available versions:"
    for version in "${!VERSIONS[@]}"; do
        php_version=${VERSIONS[$version]}
        echo "  • $version (PHP $php_version)"
    done
    echo ""
    echo "Platforms: $PLATFORMS"
    echo ""
    echo "Examples:"
    echo "  $0                    # Build all versions"
    echo "  $0 6.7.1.0           # Build specific version"
    echo "  $0 6.7.1.0 linux/amd64  # Build for specific platform"
    echo ""
}

build_image() {
    local version=$1
    local php_version=$2
    local platform=${3:-$PLATFORMS}
    
    echo -e "${BLUE}🏗️ Building Shopware $version (PHP $php_version)${NC}"
    echo "Platform: $platform"
    echo ""
    
    # Create build context directory
    local build_dir="build/$version"
    mkdir -p "$build_dir"
    
    # Copy Dockerfile and modify for specific version
    sed "s/ENV SHOPWARE_VERSION=.*/ENV SHOPWARE_VERSION=$version/" Dockerfile > "$build_dir/Dockerfile"
    sed -i "s/ENV PHP_VERSION=.*/ENV PHP_VERSION=$php_version/" "$build_dir/Dockerfile"
    
    # Copy configuration files
    cp apache-shopware.conf "$build_dir/"
    cp .env.dev "$build_dir/"
    cp supervisord.conf "$build_dir/"
    cp start.sh "$build_dir/"
    
    # Build and push image
    local tag="$REGISTRY/$IMAGE_NAME:$version"
    local latest_tag="$REGISTRY/$IMAGE_NAME:latest"
    
    echo -e "${YELLOW}🔨 Building image: $tag${NC}"
    
    if docker buildx build \
    --platform "$platform" \
    --build-arg SHOPWARE_VERSION="$version" \
    --build-arg PHP_VERSION="$php_version" \
    --tag "$tag" \
    --tag "$REGISTRY/$IMAGE_NAME:${version%.*.*}" \
    --push \
    "$build_dir"; then
        
        echo -e "${GREEN}✅ Successfully built: $tag${NC}"
        
        # Tag latest if this is the newest version
        if [ "$version" == "6.7.1.0" ]; then
            docker buildx imagetools create "$tag" --tag "$latest_tag"
            echo -e "${GREEN}✅ Tagged as latest: $latest_tag${NC}"
        fi
        
        echo ""
    else
        echo -e "${RED}❌ Failed to build: $tag${NC}"
        exit 1
    fi
}

validate_version() {
    local version=$1
    if [[ ! " ${!VERSIONS[@]} " =~ " ${version} " ]]; then
        echo -e "${RED}❌ Invalid version: $version${NC}"
        echo "Available versions: ${!VERSIONS[@]}"
        exit 1
    fi
}

main() {
    local version=$1
    local platform=$2
    
    # Show help if requested
    if [[ "$1" == "-h" || "$1" == "--help" ]]; then
        print_help
        exit 0
    fi
    
    # Setup Docker Buildx if not exists
    if ! docker buildx ls | grep -q "shopware-builder"; then
        echo -e "${BLUE}🔧 Setting up Docker Buildx...${NC}"
        docker buildx create --name shopware-builder --use
    fi
    
    echo -e "${BLUE}🚀 Shopware Development Image Builder${NC}"
    echo "===================================="
    echo ""
    
    # Build specific version or all versions
    if [[ -n "$version" ]]; then
        validate_version "$version"
        php_version=${VERSIONS[$version]}
        build_image "$version" "$php_version" "$platform"
    else
        echo -e "${YELLOW}📦 Building all versions...${NC}"
        echo ""
        
        # Sort versions to build in order
        for version in $(printf '%s\n' "${!VERSIONS[@]}" | sort -V); do
            php_version=${VERSIONS[$version]}
            build_image "$version" "$php_version" "$platform"
        done
    fi
    
    echo -e "${GREEN}🎉 Build process completed!${NC}"
    echo ""
    echo "Available images:"
    for version in "${!VERSIONS[@]}"; do
        echo "  • $REGISTRY/$IMAGE_NAME:$version"
    done
    echo "  • $REGISTRY/$IMAGE_NAME:latest (6.7.1.0)"
    echo ""
}

# Cleanup function
cleanup() {
    echo -e "${YELLOW}🧹 Cleaning up build directories...${NC}"
    rm -rf build/
}

# Set trap for cleanup
trap cleanup EXIT

# Run main function
main "$@"
#!/bin/bash
# Build script for Shopware Docker images

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Default values
VERSION=${1:-6.7}
PHP_VERSION=""
COMMIT=""

echo -e "${GREEN}Building Shopware Docker image for version ${VERSION}${NC}"

# Determine PHP version based on Shopware version
case "$VERSION" in
    6.5)
        PHP_VERSION="8.1"
        ;;
    6.6)
        PHP_VERSION="8.2"
        ;;
    6.7)
        PHP_VERSION="8.3"
        ;;
    *)
        echo -e "${RED}Unsupported Shopware version: $VERSION${NC}"
        echo "Supported versions: 6.5, 6.6, 6.7"
        exit 1
        ;;
esac

echo -e "${YELLOW}Using PHP version: ${PHP_VERSION}${NC}"

# Get latest commit for the version (optional)
if command -v curl &> /dev/null && command -v jq &> /dev/null; then
    echo -e "${YELLOW}Fetching latest commit for Shopware ${VERSION}...${NC}"
    LATEST_TAG=$(curl -s "https://api.github.com/repos/shopware/shopware/tags" | \
        jq -r --arg version "v${VERSION}" \
        '[.[] | select(.name | startswith($version))] | sort_by(.name) | reverse | .[0].name // empty')
    
    if [ -n "$LATEST_TAG" ]; then
        COMMIT=$(curl -s "https://api.github.com/repos/shopware/shopware/git/refs/tags/$LATEST_TAG" | jq -r '.object.sha // empty')
        echo -e "${GREEN}Latest tag: ${LATEST_TAG} (${COMMIT})${NC}"
    else
        echo -e "${YELLOW}No specific tag found, using branch latest${NC}"
    fi
fi

# Build command
BUILD_ARGS="--build-arg SHOPWARE_VERSION=${VERSION} --build-arg PHP_VERSION=${PHP_VERSION}"
if [ -n "$COMMIT" ]; then
    BUILD_ARGS="${BUILD_ARGS} --build-arg SHOPWARE_COMMIT=${COMMIT}"
fi

echo -e "${YELLOW}Building Docker image...${NC}"
docker build ${BUILD_ARGS} -t shopware-dev:${VERSION} .

echo -e "${GREEN}✅ Build completed successfully!${NC}"
echo -e "${YELLOW}Image: shopware-dev:${VERSION}${NC}"
echo ""
echo "To run the container:"
echo "docker run -d --name shopware-dev-${VERSION} -p 8080:80 -p 3306:3306 shopware-dev:${VERSION}"
echo ""
echo "Access URLs:"
echo "  Frontend: http://localhost:8080"
echo "  Admin: http://localhost:8080/admin"
echo "  Default credentials: admin / shopware"

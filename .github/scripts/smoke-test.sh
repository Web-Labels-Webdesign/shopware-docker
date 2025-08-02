#!/bin/bash
set -e

SHOPWARE_VERSION=${1:-"6.6"}
IMAGE_NAME="ghcr.io/${GITHUB_REPOSITORY_OWNER:-shopware}/shopware-dev:${SHOPWARE_VERSION}"
CONTAINER_NAME="shopware-test-${SHOPWARE_VERSION}-$$"

echo "🚀 Starting smoke test for Shopware ${SHOPWARE_VERSION}"

# Start container in background
echo "📦 Starting container: ${IMAGE_NAME}"
docker run -d \
  --name "${CONTAINER_NAME}" \
  -e SHOPWARE_VERSION="${SHOPWARE_VERSION}" \
  -e XDEBUG_ENABLED=0 \
  -p 8080:80 \
  -p 8081:8080 \
  -p 3307:3306 \
  -p 9201:9200 \
  "${IMAGE_NAME}"

# Wait for services to start
echo "⏳ Waiting for services to start..."
sleep 60

# Function to cleanup on exit
cleanup() {
  echo "🧹 Cleaning up container..."
  docker stop "${CONTAINER_NAME}" >/dev/null 2>&1 || true
  docker rm "${CONTAINER_NAME}" >/dev/null 2>&1 || true
}
trap cleanup EXIT

# Test 1: Check if Shopware console is working
echo "🔍 Testing Shopware console..."
docker exec "${CONTAINER_NAME}" bin/console system:info

# Test 2: Check if storefront is accessible
echo "🌐 Testing storefront..."
curl --fail --silent --max-time 30 http://localhost:8080/ > /dev/null

# Test 3: Check if admin is accessible
echo "🔐 Testing admin interface..."
curl --fail --silent --max-time 30 http://localhost:8080/admin > /dev/null

# Test 4: Check if Adminer is accessible
echo "🗄️ Testing Adminer..."
curl --fail --silent --max-time 30 http://localhost:8081/ > /dev/null

# Test 5: Check MySQL/MariaDB connection
echo "💾 Testing database connection..."
docker exec "${CONTAINER_NAME}" mysql -u root -proot -e "SHOW DATABASES;" > /dev/null

# Test 6: Check Redis (if available)
echo "🔴 Testing Redis connection..."
docker exec "${CONTAINER_NAME}" redis-cli ping || echo "⚠️ Redis not available or not responding"

# Test 7: Check Elasticsearch (for 6.7.x)
if [ "${SHOPWARE_VERSION}" = "6.7" ]; then
  echo "🔍 Testing Elasticsearch (required for 6.7.x)..."
  curl --fail --silent --max-time 30 http://localhost:9201/_cluster/health > /dev/null
else
  echo "ℹ️ Skipping Elasticsearch test for version ${SHOPWARE_VERSION}"
fi

echo "✅ All smoke tests passed for Shopware ${SHOPWARE_VERSION}!"
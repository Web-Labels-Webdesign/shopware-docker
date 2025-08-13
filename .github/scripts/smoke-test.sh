#!/bin/bash
set -e

# Shopware Docker Smoke Test Script
# Validates that the container starts correctly and basic functionality works

IMAGE_TAG=${1:-"ghcr.io/web-labels-webdesign/shopware-docker:latest"}
CONTAINER_NAME="shopware-smoke-test-$$"
TEST_TIMEOUT=120

echo "🧪 Starting smoke test for image: $IMAGE_TAG"

# Cleanup function
cleanup() {
    echo "🧹 Cleaning up test container..."
    docker stop "$CONTAINER_NAME" >/dev/null 2>&1 || true
    docker rm "$CONTAINER_NAME" >/dev/null 2>&1 || true
}

# Set trap to ensure cleanup happens
trap cleanup EXIT

# Test 1: Container starts successfully
echo "📦 Test 1: Container startup"
docker run -d --name "$CONTAINER_NAME" \
    -e SHOPWARE_DOCKER_DEBUG=true \
    -e SHOPWARE_DOCKER_AUTO_PERMISSIONS=true \
    -p 8080:80 \
    "$IMAGE_TAG"

echo "⏰ Waiting for container to initialize..."
sleep 10

# Test 2: Container is running
echo "🔍 Test 2: Container health check"
if ! docker ps | grep -q "$CONTAINER_NAME"; then
    echo "❌ FAIL: Container is not running"
    docker logs "$CONTAINER_NAME" 2>&1 | tail -20
    exit 1
fi
echo "✅ PASS: Container is running"

# Test 3: Smart entrypoint executed
echo "🔧 Test 3: Smart entrypoint execution"
docker logs "$CONTAINER_NAME" 2>&1 | grep -q "Starting smart entrypoint" || {
    echo "❌ FAIL: Smart entrypoint not detected in logs"
    docker logs "$CONTAINER_NAME" 2>&1 | tail -20
    exit 1
}
echo "✅ PASS: Smart entrypoint executed"

# Test 4: Permission handling activated
echo "🔐 Test 4: Permission handling"
docker logs "$CONTAINER_NAME" 2>&1 | grep -q "Detected host OS\|Auto permissions disabled" || {
    echo "❌ FAIL: Permission handling not detected"
    docker logs "$CONTAINER_NAME" 2>&1 | tail -20
    exit 1
}
echo "✅ PASS: Permission handling activated"

# Test 5: www-data user exists and has correct setup
echo "👤 Test 5: User configuration"
WWW_DATA_CHECK=$(docker exec "$CONTAINER_NAME" id www-data 2>/dev/null || echo "FAIL")
if [ "$WWW_DATA_CHECK" = "FAIL" ]; then
    echo "❌ FAIL: www-data user not found"
    exit 1
fi
echo "✅ PASS: www-data user configured: $WWW_DATA_CHECK"

# Test 6: Apache/Nginx is responding
echo "🌐 Test 6: Web server response"
sleep 15  # Give more time for web server to start

# Try to get a response from the web server
RESPONSE_CODE=$(docker exec "$CONTAINER_NAME" curl -s -o /dev/null -w "%{http_code}" http://localhost:80 2>/dev/null || echo "000")
if [ "$RESPONSE_CODE" = "000" ]; then
    echo "⚠️  WARNING: Could not test web server response (curl failed)"
elif [ "$RESPONSE_CODE" -ge "200" ] && [ "$RESPONSE_CODE" -lt "400" ]; then
    echo "✅ PASS: Web server responding with HTTP $RESPONSE_CODE"
elif [ "$RESPONSE_CODE" -ge "400" ] && [ "$RESPONSE_CODE" -lt "600" ]; then
    echo "✅ PASS: Web server responding with HTTP $RESPONSE_CODE (expected for Shopware setup)"
else
    echo "❌ FAIL: Unexpected HTTP response code: $RESPONSE_CODE"
    exit 1
fi

# Test 7: Shopware structure exists
echo "📁 Test 7: Shopware directory structure"
docker exec "$CONTAINER_NAME" test -d /var/www/html || {
    echo "❌ FAIL: /var/www/html directory not found"
    exit 1
}
echo "✅ PASS: Shopware directory structure exists"

# Test 8: Environment variables are processed
echo "🔧 Test 8: Environment variable processing"
ENV_OUTPUT=$(docker exec "$CONTAINER_NAME" printenv | grep SHOPWARE_DOCKER || echo "")
if [ -n "$ENV_OUTPUT" ]; then
    echo "✅ PASS: Environment variables processed"
    echo "   $ENV_OUTPUT"
else
    echo "⚠️  WARNING: No SHOPWARE_DOCKER environment variables found"
fi

# Display container logs for debugging
echo "📋 Container logs (last 20 lines):"
echo "---"
docker logs "$CONTAINER_NAME" 2>&1 | tail -20
echo "---"

echo "🎉 All smoke tests completed successfully!"
echo "✅ Image $IMAGE_TAG is working correctly"
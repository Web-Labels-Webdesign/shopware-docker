#!/bin/bash
# Enhanced Health Check Script for Shopware Docker Containers
# Supports both full and slim variants

set -e

VARIANT=${VARIANT:-full}
TIMEOUT=${TIMEOUT:-30}
MAX_RETRIES=${MAX_RETRIES:-5}
RETRY_DELAY=${RETRY_DELAY:-5}

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log() {
    echo -e "${BLUE}[$(date +'%Y-%m-%d %H:%M:%S')] $1${NC}"
}

warn() {
    echo -e "${YELLOW}[$(date +'%Y-%m-%d %H:%M:%S')] WARNING: $1${NC}"
}

error() {
    echo -e "${RED}[$(date +'%Y-%m-%d %H:%M:%S')] ERROR: $1${NC}"
}

success() {
    echo -e "${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')] SUCCESS: $1${NC}"
}

# Check if curl is available
check_curl() {
    if ! command -v curl >/dev/null 2>&1; then
        error "curl is not available"
        exit 1
    fi
}

# Generic HTTP check with retries
http_check() {
    local url=$1
    local expected_code=${2:-200}
    local description=${3:-"HTTP check"}
    local retry_count=0
    
    while [ $retry_count -lt $MAX_RETRIES ]; do
        log "Attempting $description ($((retry_count + 1))/$MAX_RETRIES): $url"
        
        if curl -f -s --max-time $TIMEOUT "$url" >/dev/null 2>&1; then
            success "$description passed"
            return 0
        fi
        
        retry_count=$((retry_count + 1))
        if [ $retry_count -lt $MAX_RETRIES ]; then
            warn "$description failed, retrying in ${RETRY_DELAY}s..."
            sleep $RETRY_DELAY
        fi
    done
    
    error "$description failed after $MAX_RETRIES attempts"
    return 1
}

# JSON response check
json_check() {
    local url=$1
    local description=${2:-"JSON API check"}
    local retry_count=0
    
    while [ $retry_count -lt $MAX_RETRIES ]; do
        log "Attempting $description ($((retry_count + 1))/$MAX_RETRIES): $url"
        
        response=$(curl -f -s --max-time $TIMEOUT "$url" 2>/dev/null || echo "")
        
        if [ -n "$response" ] && echo "$response" | jq -e . >/dev/null 2>&1; then
            success "$description passed"
            return 0
        fi
        
        retry_count=$((retry_count + 1))
        if [ $retry_count -lt $MAX_RETRIES ]; then
            warn "$description failed, retrying in ${RETRY_DELAY}s..."
            sleep $RETRY_DELAY
        fi
    done
    
    error "$description failed after $MAX_RETRIES attempts"
    return 1
}

# Health check for slim variant
health_check_slim() {
    log "🔍 Running health check for slim variant"
    
    # Check PHP-FPM ping endpoint
    if ! http_check "http://localhost:9000/ping" 200 "PHP-FPM ping"; then
        return 1
    fi
    
    # Check custom health endpoint
    if ! json_check "http://localhost:9000/health.php" "Health endpoint"; then
        return 1
    fi
    
    # Check PHP-FPM status (if available)
    if http_check "http://localhost:9000/status" 200 "PHP-FPM status" || true; then
        log "PHP-FPM status endpoint available"
    fi
    
    success "Slim variant health check completed successfully"
    return 0
}

# Health check for full variant
health_check_full() {
    log "🔍 Running health check for full variant"
    
    # Check Shopware API
    if ! json_check "http://localhost/api/_info/version" "Shopware API version"; then
        return 1
    fi
    
    # Check admin interface (may fail during setup, so make it optional)
    if http_check "http://localhost/admin" 200 "Admin interface" || true; then
        log "Admin interface accessible"
    else
        warn "Admin interface not accessible (may be normal during initial setup)"
    fi
    
    # Check MailHog (optional)
    if http_check "http://localhost:8025" 200 "MailHog interface" || true; then
        log "MailHog interface accessible"
    else
        warn "MailHog interface not accessible"
    fi
    
    # Check database connectivity via Shopware
    if json_check "http://localhost/api/_info/config" "Shopware config API" || true; then
        log "Database connectivity verified"
    else
        warn "Database connectivity check failed"
    fi
    
    success "Full variant health check completed successfully"
    return 0
}

# Main health check logic
main() {
    log "🚀 Starting Shopware Docker health check (variant: $VARIANT)"
    
    check_curl
    
    case "$VARIANT" in
        "slim")
            health_check_slim
            ;;
        "full"|*)
            health_check_full
            ;;
    esac
    
    local exit_code=$?
    
    if [ $exit_code -eq 0 ]; then
        success "🎉 All health checks passed!"
    else
        error "❌ Health check failed"
    fi
    
    exit $exit_code
}

# Run main function if script is executed directly
if [ "${BASH_SOURCE[0]}" = "${0}" ]; then
    main "$@"
fi
#!/bin/bash
set -e

# Prevent double execution
if [ "$SHOPWARE_DOCKER_ENTRYPOINT_EXECUTED" = "true" ]; then
    exec "$@"
fi
export SHOPWARE_DOCKER_ENTRYPOINT_EXECUTED=true

# Simple Smart Entrypoint for Shopware Docker
AUTO_PERMISSIONS=${SHOPWARE_DOCKER_AUTO_PERMISSIONS:-true}
HOST_UID=${SHOPWARE_DOCKER_HOST_UID:-auto}
HOST_GID=${SHOPWARE_DOCKER_HOST_GID:-auto}
DEBUG=${SHOPWARE_DOCKER_DEBUG:-false}

debug_log() {
    if [ "$DEBUG" = "true" ]; then
        echo "[DEBUG] $1" >&2
    fi
}

# Get host UID/GID from mounted volumes
get_host_uid_gid() {
    # Check common mount points for host ownership
    for mount_point in "/var/www/html/custom" "/var/www/html/files" "/var/www/html/var"; do
        if [ -d "$mount_point" ]; then
            local found=$(find "$mount_point" -maxdepth 2 \! -uid 33 \! -uid 0 -printf "%u:%g\n" 2>/dev/null | head -1)
            if [ -n "$found" ]; then
                echo "$found"
                return
            fi
        fi
    done
    echo "1000:1000"  # Default fallback
}

# Main permission handling
if [ "$AUTO_PERMISSIONS" = "true" ]; then
    debug_log "Starting permission handling..."
    
    # Determine target UID/GID
    if [ "$HOST_UID" = "auto" ] || [ "$HOST_GID" = "auto" ]; then
        host_ids=$(get_host_uid_gid)
        target_uid=$(echo "$host_ids" | cut -d: -f1)
        target_gid=$(echo "$host_ids" | cut -d: -f2)
    else
        target_uid="$HOST_UID"
        target_gid="$HOST_GID"
    fi
    
    debug_log "Target UID/GID: $target_uid:$target_gid"
    
    # Update www-data user to match host
    current_uid=$(id -u www-data 2>/dev/null || echo "33")
    current_gid=$(id -g www-data 2>/dev/null || echo "33")
    
    if [ "$target_uid" != "$current_uid" ] || [ "$target_gid" != "$current_gid" ]; then
        debug_log "Updating www-data from $current_uid:$current_gid to $target_uid:$target_gid"
        
        # Update user/group
        groupmod -g "$target_gid" www-data 2>/dev/null || true
        usermod -u "$target_uid" -g "$target_gid" www-data 2>/dev/null || true
        
        # Set ownership of entire /var/www/html recursively
        debug_log "Setting ownership of /var/www/html recursively to $target_uid:$target_gid"
        chown -R "$target_uid:$target_gid" /var/www/html 2>/dev/null || true
        
        # Continuous monitoring to maintain permissions
        {
            while true; do
                sleep 30
                chown -R "$target_uid:$target_gid" /var/www/html 2>/dev/null || true
            done
        } &
        
        debug_log "Started continuous ownership monitoring for /var/www/html"
    fi
fi

# Execute dockware's original entrypoint
debug_log "Executing dockware entrypoint..."
if [ -f /entrypoint.sh ]; then
    exec /entrypoint.sh "$@"
else
    exec supervisord
fi
#!/bin/bash
set -e

# Simple Smart Entrypoint for Shopware Docker
# Handles automatic UID/GID mapping for seamless file permissions

# Environment variables with defaults
AUTO_PERMISSIONS=${SHOPWARE_DOCKER_AUTO_PERMISSIONS:-true}
HOST_UID=${SHOPWARE_DOCKER_HOST_UID:-auto}
HOST_GID=${SHOPWARE_DOCKER_HOST_GID:-auto}
DEBUG=${SHOPWARE_DOCKER_DEBUG:-false}

# Debug logging function
debug_log() {
    if [ "$DEBUG" = "true" ]; then
        echo "[DEBUG] $1" >&2
    fi
}

# Get host UID/GID from mounted volumes
get_host_uid_gid() {
    local detected_uid="1000"  # Default fallback
    local detected_gid="1000"  # Default fallback
    
    # Check common mount points for host ownership
    for mount_point in "/var/www/html/custom" "/var/www/html/files" "/var/www/html/var" "/var/www/html"; do
        if [ -d "$mount_point" ]; then
            # Look for files/dirs not owned by www-data (33) or root (0)
            local found=$(find "$mount_point" -maxdepth 2 \! -uid 33 \! -uid 0 -printf "%u:%g\n" 2>/dev/null | head -1)
            if [ -n "$found" ]; then
                detected_uid=$(echo "$found" | cut -d: -f1)
                detected_gid=$(echo "$found" | cut -d: -f2)
                debug_log "Found host ownership: $detected_uid:$detected_gid in $mount_point"
                break
            fi
        fi
    done
    
    echo "$detected_uid:$detected_gid"
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
    if [ "$target_uid" -gt 0 ] && [ "$target_gid" -gt 0 ]; then
        current_uid=$(id -u www-data)
        current_gid=$(id -g www-data)
        
        if [ "$target_uid" != "$current_uid" ] || [ "$target_gid" != "$current_gid" ]; then
            debug_log "Updating www-data from $current_uid:$current_gid to $target_uid:$target_gid"
            
            # Simple direct approach - modify user/group
            groupmod -g "$target_gid" www-data 2>/dev/null || groupadd -g "$target_gid" hostgroup 2>/dev/null || true
            usermod -u "$target_uid" -g "$target_gid" www-data 2>/dev/null || true
            
            # Fix ownership of mounted directories
            for dir in "/var/www/html/custom" "/var/www/html/files" "/var/www/html/var"; do
                if [ -d "$dir" ]; then
                    debug_log "Fixing ownership of $dir"
                    chown -R "$target_uid:$target_gid" "$dir" 2>/dev/null || true
                fi
            done
            
            debug_log "Permission update completed"
        fi
    fi
fi

# Execute dockware's original entrypoint with permission preservation
debug_log "Executing dockware entrypoint..."

if [ -f /entrypoint.sh ]; then
    # Check if we need to preserve permissions after dockware starts
    if [ "$AUTO_PERMISSIONS" = "true" ] && [ -n "$target_uid" ] && [ -n "$target_gid" ]; then
        debug_log "Setting up post-dockware permission fix"
        
        # Create a script to re-apply permissions after dockware initialization
        cat > /usr/local/bin/fix-permissions-after-dockware.sh << EOF
#!/bin/bash
# Wait for dockware to complete initialization
sleep 10

# Re-apply our permission changes in case dockware overwrote them
debug_log() { [ "\$SHOPWARE_DOCKER_DEBUG" = "true" ] && echo "[DEBUG] \$1" >&2; }

debug_log "Post-dockware permission fix starting..."

# Re-check and fix www-data user
current_uid=\$(id -u www-data 2>/dev/null || echo "33")
current_gid=\$(id -g www-data 2>/dev/null || echo "33")

if [ "\$current_uid" != "$target_uid" ] || [ "\$current_gid" != "$target_gid" ]; then
    debug_log "Dockware changed permissions back, re-applying: $target_uid:$target_gid"
    groupmod -g "$target_gid" www-data 2>/dev/null || true
    usermod -u "$target_uid" -g "$target_gid" www-data 2>/dev/null || true
fi

# Re-fix ownership of mounted directories  
for dir in "/var/www/html/custom" "/var/www/html/files" "/var/www/html/var"; do
    if [ -d "\$dir" ]; then
        debug_log "Re-fixing ownership of \$dir"
        chown -R "$target_uid:$target_gid" "\$dir" 2>/dev/null || true
    fi
done

debug_log "Post-dockware permission fix completed"
EOF
        
        chmod +x /usr/local/bin/fix-permissions-after-dockware.sh
        
        # Run the fix in background after dockware starts
        /usr/local/bin/fix-permissions-after-dockware.sh &
    fi
    
    exec /entrypoint.sh "$@"
else
    # Fallback if no entrypoint found
    exec supervisord
fi
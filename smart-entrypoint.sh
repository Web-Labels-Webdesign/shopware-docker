#!/bin/bash
set -e

# Smart Entrypoint for Shopware Docker
# Handles automatic UID/GID mapping for seamless file permissions across host systems

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

# Function to detect host OS
detect_host_os() {
    # Check for common Windows indicators in container environment
    if [ -n "$PROCESSOR_ARCHITECTURE" ] || [ -n "$OS" ] || [ -f /proc/version ] && grep -q "Microsoft\|WSL" /proc/version 2>/dev/null; then
        echo "windows"
    elif [ "$(uname)" = "Darwin" ]; then
        echo "macos"
    else
        echo "linux"
    fi
}

# Function to get host UID/GID from mounted volume
get_host_ids() {
    local mount_point="/var/www/html"
    
    if [ -d "$mount_point" ]; then
        local stat_info=$(stat -c "%u:%g" "$mount_point" 2>/dev/null || echo "33:33")
        echo "$stat_info"
    else
        echo "33:33"
    fi
}

# Function to update user/group IDs
update_user_ids() {
    local new_uid=$1
    local new_gid=$2
    local current_uid=$(id -u www-data)
    local current_gid=$(id -g www-data)
    
    debug_log "Current www-data UID: $current_uid, GID: $current_gid"
    debug_log "Target UID: $new_uid, GID: $new_gid"
    
    if [ "$current_uid" != "$new_uid" ] || [ "$current_gid" != "$new_gid" ]; then
        debug_log "Updating www-data user IDs..."
        
        # Update group first
        if [ "$current_gid" != "$new_gid" ]; then
            groupmod -g "$new_gid" www-data 2>/dev/null || {
                debug_log "Failed to modify group, creating new group..."
                groupadd -g "$new_gid" www-data-new 2>/dev/null || true
                usermod -g "$new_gid" www-data 2>/dev/null || true
            }
        fi
        
        # Update user
        if [ "$current_uid" != "$new_uid" ]; then
            usermod -u "$new_uid" www-data 2>/dev/null || {
                debug_log "Failed to modify user directly, using alternative method..."
                # Alternative approach for systems where usermod fails
                sed -i "s/^www-data:x:$current_uid:$current_gid:/www-data:x:$new_uid:$new_gid:/" /etc/passwd
            }
        fi
        
        # Fix ownership of key directories
        debug_log "Fixing ownership of key directories..."
        chown -R www-data:www-data /var/www/html 2>/dev/null || true
        chown -R www-data:www-data /tmp 2>/dev/null || true
        
        debug_log "User ID update completed"
    else
        debug_log "User IDs are already correct"
    fi
}

# Main permission handling logic
handle_permissions() {
    if [ "$AUTO_PERMISSIONS" != "true" ]; then
        debug_log "Auto permissions disabled, skipping UID/GID mapping"
        return
    fi
    
    local host_os=$(detect_host_os)
    debug_log "Detected host OS: $host_os"
    
    case "$host_os" in
        "windows"|"macos")
            debug_log "Windows/macOS detected - Docker Desktop handles permissions automatically"
            ;;
        "linux")
            debug_log "Linux detected - configuring UID/GID mapping"
            
            local target_uid="$HOST_UID"
            local target_gid="$HOST_GID"
            
            # Auto-detect if needed
            if [ "$target_uid" = "auto" ] || [ "$target_gid" = "auto" ]; then
                local host_ids=$(get_host_ids)
                local detected_uid=$(echo "$host_ids" | cut -d: -f1)
                local detected_gid=$(echo "$host_ids" | cut -d: -f2)
                
                [ "$target_uid" = "auto" ] && target_uid="$detected_uid"
                [ "$target_gid" = "auto" ] && target_gid="$detected_gid"
                
                debug_log "Auto-detected UID: $detected_uid, GID: $detected_gid"
            fi
            
            # Only update if we have valid IDs and they're not the default
            if [ "$target_uid" -gt 0 ] && [ "$target_gid" -gt 0 ] && \
               ([ "$target_uid" != "33" ] || [ "$target_gid" != "33" ]); then
                update_user_ids "$target_uid" "$target_gid"
            else
                debug_log "Using default www-data IDs (33:33)"
            fi
            ;;
        *)
            debug_log "Unknown host OS, using default configuration"
            ;;
    esac
}

# Initialize permissions
debug_log "Starting smart entrypoint..."
handle_permissions

# Execute the original dockware entrypoint/command
debug_log "Executing original command: $@"

# Execute the original dockware entrypoint/command
if [ $# -eq 0 ]; then
    # Use the original dockware entrypoint
    exec /usr/local/bin/original-entrypoint.sh
else
    exec "$@"
fi
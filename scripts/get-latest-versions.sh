#!/bin/bash

# Fetch latest Shopware versions for each major branch
get_latest_version() {
    local branch=$1
    local response=$(curl -s "https://api.github.com/repos/shopware/shopware/tags?per_page=250")
    
    # Check if response is valid JSON
    if ! echo "$response" | jq empty 2>/dev/null; then
        echo "Error: Invalid JSON response from GitHub API" >&2
        echo "$response" >&2
        return 1
    fi
    
    # Extract version
    echo "$response" | \
    jq -r ".[] | select(.name | startswith(\"v${branch}.\")) | .name" | \
    sed 's/^v//' | \
    head -1
}

# Get latest versions with fallbacks
SHOPWARE_6_5=$(get_latest_version "6.5" || echo "6.5.8.18")
SHOPWARE_6_6=$(get_latest_version "6.6" || echo "6.6.10.6")
SHOPWARE_6_7=$(get_latest_version "6.7" || echo "6.7.1.1")

echo "Latest Shopware versions:"
echo "6.5: ${SHOPWARE_6_5}"
echo "6.6: ${SHOPWARE_6_6}"
echo "6.7: ${SHOPWARE_6_7}"

# Export as GitHub Actions outputs if running in CI
if [ ! -z "$GITHUB_OUTPUT" ]; then
    echo "shopware_6_5=${SHOPWARE_6_5}" >> $GITHUB_OUTPUT
    echo "shopware_6_6=${SHOPWARE_6_6}" >> $GITHUB_OUTPUT
    echo "shopware_6_7=${SHOPWARE_6_7}" >> $GITHUB_OUTPUT
fi
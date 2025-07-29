#!/bin/bash

# Fetch latest Shopware versions for each major branch
get_latest_version() {
    local branch=$1
    curl -s "https://api.github.com/repos/shopware/shopware/tags" | \
    jq -r ".[] | select(.name | startswith(\"v${branch}.\")) | .name" | \
    sed 's/^v//' | \
    head -1
}

# Get latest versions
SHOPWARE_6_5=$(get_latest_version "6.5")
SHOPWARE_6_6=$(get_latest_version "6.6") 
SHOPWARE_6_7=$(get_latest_version "6.7")

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
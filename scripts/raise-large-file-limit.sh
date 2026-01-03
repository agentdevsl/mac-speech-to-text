#!/bin/bash
# Raises the pre-commit large file limit from 500KB to 1MB
# Usage: ./scripts/raise-large-file-limit.sh

set -e

CONFIG_FILE=".pre-commit-config.yaml"

if [[ ! -f "$CONFIG_FILE" ]]; then
    echo "Error: $CONFIG_FILE not found"
    exit 1
fi

# Update the maxkb argument from 500 to 1000
sed -i 's/--maxkb=500/--maxkb=1000/' "$CONFIG_FILE"

echo "Updated large file limit to 1MB in $CONFIG_FILE"

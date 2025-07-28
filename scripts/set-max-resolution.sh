#!/usr/bin/env bash

# Script to set display to maximum resolution using displayplacer
# This script will automatically detect displays and set them to their highest resolution

set -e

# Function to log messages
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1"
}

# Function to set display to maximum resolution
set_max_resolution() {
    log "Setting displays to maximum resolution..."
    
    # Get current display information
    if ! command -v displayplacer &> /dev/null; then
        log "ERROR: displayplacer not found. Please install it via Homebrew: brew install displayplacer"
        exit 1
    fi
    
    # For MacBook built-in screen, set to maximum resolution (mode 13: 2560x1600)
    # Using contextual ID (1) which is more reliable than persistent ID
    log "Setting MacBook built-in screen to maximum resolution (2560x1600)..."
    
    if displayplacer "id:1 mode:13 degree:0" 2>/dev/null; then
        log "Successfully set display to maximum resolution"
    else
        log "WARNING: Failed to set display using contextual ID, trying with display detection..."
        
        # Fallback: Parse displayplacer list output to find the maximum resolution mode
        displayplacer list | grep -A 50 "MacBook built in screen" | grep "mode.*2560x1600" | head -1 | while read -r line; do
            if [[ $line =~ mode\ ([0-9]+):.*2560x1600 ]]; then
                mode_num="${BASH_REMATCH[1]}"
                log "Found maximum resolution at mode $mode_num, applying..."
                displayplacer "id:1 mode:$mode_num degree:0"
            fi
        done
    fi
}

# Main execution
main() {
    log "Starting display configuration..."
    set_max_resolution
    log "Display configuration completed"
}

# Run main function
main "$@"


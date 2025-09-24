#!/usr/bin/env bash

# Module Validation Script
# Validates that all modules follow the standardized interface pattern

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo "🔍 Validating module structure and compliance..."
echo

# Run the Nix validation script
if nix eval --file scripts/validate-modules.nix check 2>/dev/null; then
    echo -e "${GREEN}✅ All modules pass validation${NC}"
    echo
    
    # Show summary
    echo "📊 Validation Summary:"
    nix eval --file scripts/validate-modules.nix summary.message --raw
    echo
    
    exit 0
else
    echo -e "${RED}❌ Module validation failed${NC}"
    echo
    
    # Generate and display detailed report
    echo "📋 Detailed Validation Report:"
    echo "================================"
    nix eval --file scripts/validate-modules.nix report --raw
    echo
    
    exit 1
fi
#!/bin/bash

# Debug script to test Figma API access

set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_FILE="${SCRIPT_DIR}/.env"

# Source config
if [[ ! -f "$CONFIG_FILE" ]]; then
    echo -e "${RED}Error: .env file not found${NC}"
    exit 1
fi

source "$CONFIG_FILE"

if [[ -z "${FIGMA_API_KEY:-}" ]]; then
    echo -e "${RED}Error: FIGMA_API_KEY not set${NC}"
    exit 1
fi

FILE_ID="${FIGMA_FILE_ID:-}"
if [[ -z "$FILE_ID" ]]; then
    echo "Enter Figma File ID (from URL: figma.com/file/[FILE_ID]/name):"
    read -r FILE_ID
fi

echo -e "${BLUE}Testing Figma API access...${NC}"
echo "File ID: $FILE_ID"
echo ""

# Test API connection
echo -e "${BLUE}1. Testing API key...${NC}"
TEMP_FILE=$(mktemp)
HTTP_CODE=$(curl -s -w "%{http_code}" \
    -H "X-Figma-Token: ${FIGMA_API_KEY}" \
    "https://api.figma.com/v1/files/${FILE_ID}" \
    -o "$TEMP_FILE")
BODY=$(cat "$TEMP_FILE")
rm -f "$TEMP_FILE"

echo "HTTP Status: $HTTP_CODE"
echo ""

if [[ "$HTTP_CODE" == "200" ]]; then
    echo -e "${GREEN}✓ API key is valid and file is accessible${NC}"
    echo ""
    
    echo -e "${BLUE}2. Available pages in your file:${NC}"
    echo "$BODY" | jq -r '.document.children[] | "\(.name)"' 2>/dev/null || echo "Could not parse pages"
    echo ""
    
    echo -e "${BLUE}3. Full file structure:${NC}"
    echo "$BODY" | jq '.document.children[] | {name: .name, id: .id}' 2>/dev/null || echo "Could not parse structure"
elif [[ "$HTTP_CODE" == "403" ]]; then
    echo -e "${RED}✗ 403 Forbidden - Check these:${NC}"
    echo "  1. API key is correct and hasn't expired"
    echo "  2. File ID is correct"
    echo "  3. The file is shared with your Figma account"
    echo "  4. Your API key has permission to access this file"
    echo ""
    echo "Response: $(echo "$BODY" | jq '.message // .' 2>/dev/null || echo "$BODY")"
elif [[ "$HTTP_CODE" == "404" ]]; then
    echo -e "${RED}✗ 404 Not Found - File ID may be incorrect${NC}"
    echo "Response: $(echo "$BODY" | jq '.message // .' 2>/dev/null || echo "$BODY")"
else
    echo -e "${RED}✗ Error: HTTP $HTTP_CODE${NC}"
    echo "Response: $BODY"
fi

#!/bin/bash

# Example usage of the Figma to Bootstrap converter
# Update these values with your actual Figma details

# Your Figma file ID (from the URL: https://figma.com/file/[FILE_ID]/name)
FIGMA_FILE_ID="YOUR_FILE_ID_HERE"

# Page name as it appears in your Figma file
PAGE_NAME="Design"

# Component or frame name as it appears in your Figma file
COMPONENT_NAME="Button"

# Optional: Custom output directory (default: output)
OUTPUT_DIR="output"

# Run the converter
./figma-to-html.sh \
    -f "$FIGMA_FILE_ID" \
    -p "$PAGE_NAME" \
    -c "$COMPONENT_NAME" \
    -o "$OUTPUT_DIR"

# If successful, open the generated HTML (macOS)
if [ -f "$OUTPUT_DIR/index.html" ]; then
    echo ""
    echo "✓ Conversion successful!"
    echo "Opening HTML file..."
    open "$OUTPUT_DIR/index.html"
fi

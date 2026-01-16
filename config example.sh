#!/bin/bash

# Example configuration for Figma to Bootstrap converter
# Copy this file to config.sh and customize with your values

# Figma API Configuration
# Get your API key from: https://www.figma.com/developers/api#authentication
export FIGMA_API_KEY="YOUR_FIGMA_API_KEY"

# Figma File Configuration
# Extract from your Figma URL: https://www.figma.com/file/FILE_ID/...
export FIGMA_FILE_ID="Your_FIGMA_FILE_ID"

# Page Configuration
# Comma-separated list of page names (case-sensitive)
# Or you can use multiple -p flags when calling the script
export FIGMA_PAGE_NAMES="Your_Page_Names"

# Frame Configuration (Optional)
# Target specific frames within a page (case-sensitive)
# Comma-separated list of frame names to extract
# If not set, all components from the page will be extracted
# export FIGMA_FRAME_NAMES="Header,Hero Section,Footer"

# Output Configuration
export OUTPUT_DIR="./figma-components"

# Extract only shared components (components on multiple pages)
export SHARED_ONLY=false

# Bootstrap Configuration
export BOOTSTRAP_VERSION="5.3.2"

# Template Engine: smarty, twig, or generic
export TEMPLATE_ENGINE="smarty"

# Example usage function
run_export() {
    echo "Running Figma component export..."
    
    local args="-k $FIGMA_API_KEY -f $FIGMA_FILE_ID -o $OUTPUT_DIR -b $BOOTSTRAP_VERSION -t $TEMPLATE_ENGINE"
    
    # Add page names (support comma-separated format)
    args="$args -p $FIGMA_PAGE_NAMES"
    
    # Add frame names if specified (support comma-separated format)
    if [ ! -z "$FIGMA_FRAME_NAMES" ]; then
        args="$args -r $FIGMA_FRAME_NAMES"
    fi
    
    # Add shared-only flag if enabled
    if [ "$SHARED_ONLY" = true ]; then
        args="$args --shared-only"
    fi
    
    ./figma-to-bootstrap.sh $args
}

# Uncomment to run automatically when sourcing this file
# run_export

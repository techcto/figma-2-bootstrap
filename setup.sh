#!/bin/bash

# Quick setup script for the Figma to Bootstrap converter

echo "🚀 Setting up Figma to Bootstrap converter..."
echo ""

# Check for dependencies
echo "Checking dependencies..."
missing_deps=()

if ! command -v node &> /dev/null; then
    missing_deps+=("node")
fi

if ! command -v jq &> /dev/null; then
    missing_deps+=("jq")
fi

if ! command -v curl &> /dev/null; then
    missing_deps+=("curl")
fi

if [ ${#missing_deps[@]} -gt 0 ]; then
    echo "❌ Missing dependencies: ${missing_deps[*]}"
    echo ""
    echo "Install them with:"
    echo "  brew install ${missing_deps[*]}"
    exit 1
fi

echo "✓ All dependencies found"
echo ""

# Make the main script executable
echo "Making scripts executable..."
chmod +x figma-to-html.sh
echo "✓ figma-to-html.sh is now executable"
echo ""

# Check for .env file
if [ ! -f .env ]; then
    echo "⚠️  .env file not found. Creating from .env.example..."
    cp .env.example .env
    echo "✓ .env file created"
    echo ""
    echo "⚠️  Please edit .env and add your Figma API key:"
    echo "  - Open .env in your editor"
    echo "  - Replace 'your_figma_api_key_here' with your actual API key"
    echo "  - Save the file"
    echo ""
    echo "Get your API key from: https://www.figma.com/developers/api#authentication"
else
    echo "✓ .env file already exists"
fi

echo ""
echo "✅ Setup complete!"
echo ""
echo "Next steps:"
echo "  1. Get your Figma File ID from the URL: https://figma.com/file/[FILE_ID]/name"
echo "  2. Run: ./figma-to-html.sh --help"
echo "  3. Convert your first frame:"
echo "     ./figma-to-html.sh -f YOUR_FILE_ID -p \"Page Name\" -c \"Component Name\""
echo ""

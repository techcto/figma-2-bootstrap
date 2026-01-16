# Figma to Bootstrap Components - Usage Guide

## Quick Start

### Prerequisites

1. Use a Bash shell:
   - macOS: Terminal
   - Windows: Git Bash

2. Install required dependencies (curl + jq):
   - macOS (Homebrew):
```bash
brew install jq
```
   - Windows (winget):
```bash
winget install jqlang.jq
```
   - curl is included with macOS and Windows by default.

2. Get your Figma API key:
   - Go to https://www.figma.com/
   - Click on your profile → Settings
   - Scroll to "Personal Access Tokens"
   - Create a new token

3. Get your Figma File ID:
   - Open your Figma file
   - Copy the file ID from the URL: `https://www.figma.com/file/FILE_ID/...`

### Basic Usage

```bash
# Single page
  source config.sh && ./figma-to-bootstrap.sh \
  -k YOUR_FIGMA_API_KEY \
  -f YOUR_FILE_ID \
  -p "Page, Components" \
  -r "Homepage" \
  --output-frame-html \
  --frame-name "Homepage"

# Multiple pages (comma-separated)
source config.sh && ./figma-to-bootstrap.sh \
  -k YOUR_FIGMA_API_KEY \
  -f YOUR_FILE_ID \
  -p "Components,Forms,Layouts"

# Multiple pages (multiple flags)
source config.sh && ./figma-to-bootstrap.sh \
  -k YOUR_FIGMA_API_KEY \
  -f YOUR_FILE_ID \
  -p "Components" \
  -p "Forms" \
  -p "Layouts"
```

### Advanced Usage

```bash
# Extract from multiple pages with shared component detection
./figma-to-bootstrap.sh \
  --api-key YOUR_FIGMA_API_KEY \
  --file-id YOUR_FILE_ID \
  --page-names "Components,Forms,Layouts" \
  --output-dir ./my-components \
  --bootstrap 5.3.2 \
  --template-engine smarty

# Extract specific frames from a page (comma-separated)
./figma-to-bootstrap.sh \
  -k YOUR_FIGMA_API_KEY \
  -f YOUR_FILE_ID \
  -p "Homepage" \
  -r "Header,Hero Section,Footer"

# Extract specific frames (multiple flags)
./figma-to-bootstrap.sh \
  -k YOUR_FIGMA_API_KEY \
  -f YOUR_FILE_ID \
  -p "Homepage" \
  -r "Header" \
  -r "Footer"

# Extract only shared components (used across multiple pages)
./figma-to-bootstrap.sh \
  -k YOUR_FIGMA_API_KEY \
  -f YOUR_FILE_ID \
  -p "Page1,Page2,Page3" \
  --shared-only
```

### Using Environment Variables

```bash
export FIGMA_API_KEY="your-api-key-here"

./figma-to-bootstrap.sh \
  -f YOUR_FILE_ID \
  -p "Components"
```

## Options

| Flag | Long Form | Description | Required | Default |
|------|-----------|-------------|----------|---------|
| `-k` | `--api-key` | Figma API key | Yes* | - |
| `-f` | `--file-id` | Figma file ID | Yes | - |
| `-p` | `--page-names` | Page names (comma-separated or multiple flags) | Yes | - |
| `-r` | `--frame-names` | Frame names to extract (comma-separated or multiple flags) | No | - |
| `-o` | `--output-dir` | Output directory | No | `./figma-components` |
| `-b` | `--bootstrap` | Bootstrap version | No | `5.3.2` |
| `-t` | `--template-engine` | Template engine (smarty/twig/generic) | No | `smarty` |
| `-s` | `--shared-only` | Extract only shared components | No | `false` |
| `-h` | `--help` | Show help message | No | - |

*Required unless set via `FIGMA_API_KEY` environment variable

## Output Structure

```
figma-components/
├── html/
│   ├── index.html                # Component library browser
│   ├── shared/                   # Components used on multiple pages
│   │   ├── button.html
│   │   ├── card.html
│   │   └── ...
│   ├── components/               # Page-specific components
│   ├── forms/
│   ├── layouts/
│   └── ...
├── tpl/
│   ├── shared/                   # Shared templates
│   │   ├── button.tpl
│   │   ├── card.tpl
│   │   └── ...
│   ├── components/               # Page-specific templates
│   ├── forms/
│   ├── layouts/
│   └── ...
├── metadata/
│   ├── shared/                   # Component metadata
│   ├── components/
│   ├── forms/
│   └── ...
├── all-components.json           # All components with page tracking
├── shared-components.json        # Shared components only
├── page-*-components.json        # Per-page component lists
├── figma-data.json               # Complete Figma file data
└── README.md
```

## Shared vs Page-Specific Components

The script automatically identifies **shared components** - components that appear with the same name on multiple pages. These are placed in dedicated `shared/` directories.

**Benefits:**
- Identify your reusable design system components
- Avoid duplicating code across pages
- Maintain consistency
- Build a component library efficiently

## Template Engine Support

### Smarty (default)
```bash
./figma-to-bootstrap.sh -k API_KEY -f FILE_ID -p "Components" -t smarty
```

Template syntax:
```smarty
{$variable}
{$variable|default:"fallback"}
{* Comment *}
```

### Twig
```bash
./figma-to-bootstrap.sh -k API_KEY -f FILE_ID -p "Components" -t twig
```

Template syntax:
```twig
{{ variable }}
{{ variable|default('fallback') }}
{# Comment #}
```

### Generic
```bash
./figma-to-bootstrap.sh -k API_KEY -f FILE_ID -p "Components" -t generic
```

Basic HTML comments and placeholders.

## Example Workflow

### Step 1: Export Components from Multiple Pages
```bash
./figma-to-bootstrap.sh \
  -k figd_abc123... \
  -f AbC123XyZ \
  -p "UI Components,Forms,Pages" \
  -o ./website-components
```

### Step 2: Review Output Structure
```bash
cd website-components

# Open the component browser
open html/index.html  # macOS
# or
explorer.exe html/index.html  # Windows

# Check shared components
ls -la html/shared/
ls -la tpl/shared/

# Check page-specific components
ls -la html/ui-components/
ls -la html/forms/
```

### Step 3: Prioritize Shared Components
Start by customizing shared components since they're used across multiple pages:
```bash
# View shared components list
cat shared-components.json | jq -r '.[] | .name'

# These represent your design system - implement them first!
```

### Step 4: Customize Components
Open each HTML file in a browser and customize the Bootstrap structure to match your Figma design.

### Step 5: Integrate into Your Project
Copy templates to your project:
```bash
# Shared components go in your component library
cp -r tpl/shared/* /path/to/your/project/templates/components/

# Page-specific templates
cp -r tpl/forms/* /path/to/your/project/templates/forms/
```

## Tips & Best Practices

### 1. Organize Your Figma File
- Create dedicated pages for different component categories (e.g., "Components", "Forms", "Layouts")
- Name components consistently across pages
- Use the same component name if it should be treated as shared
- Use Figma's component naming conventions (e.g., "Button/Primary", "Card/Default")

### 2. Leverage Multi-Page Extraction
- Process all relevant pages in one command
- The script will automatically identify components that appear on multiple pages
- Review the `shared-components.json` file to see your reusable components

### 3. Build Your Component Library
Priority order for implementation:
1. **Shared components first** - These are used across multiple pages
2. **High-frequency page components** - Used often within their page
3. **One-off components** - Page-specific, low-reuse components

### 4. Component Naming and Organization
- Component names are converted to lowercase with hyphens
- "Primary Button" becomes "primary-button.html"
- Special characters are removed
- Components with the same name across pages are automatically identified as shared
- Directory structure: `shared/` for multi-page components, `page-name/` for page-specific

### 5. Customization
The generated files are **starting points**. You'll need to:
- Match exact colors from Figma (use design tokens)
- Implement precise spacing and typography
- Add interactive behaviors (modals, dropdowns, etc.)
- Implement responsive breakpoints
- Add accessibility attributes

### 6. Design Tokens
Consider creating a CSS variables file for design tokens:
```css
:root {
  --primary-color: #007bff;
  --secondary-color: #6c757d;
  --spacing-sm: 0.5rem;
  --spacing-md: 1rem;
  --font-family: 'Helvetica Neue', sans-serif;
}
```

### 7. Bootstrap Customization
Customize Bootstrap to match your Figma design:
- Use Bootstrap's Sass variables
- Override default styles
- Create custom utility classes

## Troubleshooting

### "Missing required dependencies"
Install jq and ensure curl is available:
```bash
brew install jq  # macOS
winget install jqlang.jq  # Windows
```

### "Error fetching Figma data"
- Verify your API key is correct
- Check that the File ID is valid
- Ensure you have access to the Figma file

### "No components found"
- Verify the page name is correct (case-sensitive)
- Ensure the page contains components (not just frames)
- Check that components are properly created in Figma

### API Rate Limits
Figma's API has rate limits. If you encounter errors:
- Wait a few minutes between requests
- Process files in smaller batches

## Advanced Features

### Export Component Images
To export component images as PNG files, you can modify the script or use the Figma API directly:

```bash
curl -H "X-Figma-Token: YOUR_API_KEY" \
  "https://api.figma.com/v1/images/FILE_ID?ids=NODE_ID&format=png&scale=2"
```

### Batch Processing
Process multiple pages:
```bash
for page in "Components" "Layouts" "Forms"; do
  ./figma-to-bootstrap.sh -k $FIGMA_API_KEY -f $FILE_ID -p "$page" -o "./output-$page"
done
```

### Extract Only Shared Components
When you want to focus on building a component library:
```bash
# First, identify shared components across all pages
./figma-to-bootstrap.sh \
  -k $FIGMA_API_KEY \
  -f $FILE_ID \
  -p "Page1,Page2,Page3" \
  --shared-only \
  -o ./design-system

# This will only export components that appear on multiple pages
```

### Integration with CI/CD
Add to your build pipeline:
```yaml
# Example GitHub Actions workflow
- name: Export Figma Components
  run: |
    ./figma-to-bootstrap.sh \
      -k ${{ secrets.FIGMA_API_KEY }} \
      -f ${{ vars.FIGMA_FILE_ID }} \
      -p "Components" \
      -o ./src/components
```

## Related Resources

- [Figma API Documentation](https://www.figma.com/developers/api)
- [Bootstrap Documentation](https://getbootstrap.com/docs/)
- [Bootstrap Icons](https://icons.getbootstrap.com/)
- [Figma Best Practices](https://www.figma.com/best-practices/)

## License

This script is provided as-is for personal and commercial use.

## Support

For issues or questions:
1. Check the troubleshooting section above
2. Review the Figma API documentation
3. Ensure all dependencies are installed
4. Verify your API credentials and file access

## Changelog

### Version 1.0.0
- Initial release
- Support for Figma API integration
- HTML and TPL file generation
- Bootstrap 5 integration
- Multiple template engine support

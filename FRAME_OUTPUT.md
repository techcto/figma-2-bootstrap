# Frame HTML Output Feature

## Overview

The `--output-frame-html` flag allows you to generate a single, complete HTML file for a specific Figma frame that includes all child components within that frame. This is useful for previewing or sharing frame designs with all their components included.

## Usage

```bash
./figma-to-bootstrap.sh \
  -k YOUR_FIGMA_API_KEY \
  -f YOUR_FILE_ID \
  -p "Page Name" \
  -r "Frame Name" \
  --output-frame-html \
  --frame-name "Frame Name"
```

## Parameters

- `-k, --api-key KEY` - Your Figma API key
- `-f, --file-id ID` - The Figma file ID containing the frame
- `-p, --page-names NAMES` - The page name containing the frame
- `-r, --frame-names NAMES` - The frame name(s) to extract
- `-o, --output-dir DIR` - Output directory (default: `./figma-components`)
- `--output-frame-html` - Enables the frame HTML output mode
- `--frame-name FRAME` - The specific frame name to output as complete HTML

## Example

```bash
./figma-to-bootstrap.sh \
  -k abc123def456 \
  -f xyz789file \
  -p "Homepage" \
  -r "Hero Section" \
  --output-frame-html \
  --frame-name "Hero Section"
```

This will:
1. Fetch your Figma file data
2. Extract all frames named "Hero Section" from the "Homepage" page
3. Extract all components within those frames
4. Generate a complete, styled HTML file at `figma-components/Hero-Section.html`

## Output Structure

The generated HTML file includes:

- **Frame Header** - Shows the frame name and source page
- **Component Sections** - Each child component within the frame is displayed in its own styled card section
- **Metadata** - Shows component positions and IDs for reference
- **Bootstrap Styling** - Uses Bootstrap CSS for consistent, professional styling
- **Responsive Layout** - The output HTML is fully responsive

## HTML Features

The generated HTML includes:

- **Bootstrap CSS** - Full Bootstrap framework for styling
- **Component Cards** - Each component is displayed in a card with visual separation
- **Position Information** - Shows the original position/bounds from Figma
- **Clean Layout** - Professional styling with proper spacing and colors
- **Self-contained** - The HTML file includes all necessary CSS and can be opened in any browser

## Example Output

```html
<!DOCTYPE html>
<html lang="en">
<head>
    <title>Hero Section - Complete Frame</title>
    <!-- Bootstrap CSS included -->
</head>
<body>
    <div class="frame-wrapper">
        <div class="frame-header">
            <h1>Hero Section</h1>
            <div class="frame-meta">Source: Figma Page: Homepage</div>
        </div>
        <div class="frame-content">
            <div class="component-section">
                <h3>📦 Main Title</h3>
                <!-- Component content -->
            </div>
            <div class="component-section">
                <h3>📦 CTA Button</h3>
                <!-- Component content -->
            </div>
        </div>
    </div>
</body>
</html>
```

## Notes

- The `--frame-name` must exactly match the frame name in Figma
- You must specify both `-r` (frame names to extract) and `--frame-name` (the specific frame to output)
- Components within the frame are automatically discovered and included
- The output file is named based on the frame name (spaces converted to hyphens)

## Comparison with Standard Mode

| Feature | Standard Mode | Frame HTML Mode |
|---------|---------------|-----------------|
| Extracts components | ✓ | ✓ |
| Creates individual files | ✓ | ✗ |
| Creates complete frame file | ✗ | ✓ |
| Includes component hierarchy | ✗ | ✓ |
| Single HTML output | ✗ | ✓ |
| Best for | Reusable component library | Frame preview/sharing |

# Figma to Bootstrap HTML/CSS Converter

Convert Figma frames and components to pixel-perfect, semantic HTML and CSS using Bootstrap 5.3 utilities and responsive classes.

## Features

- 🎨 Convert Figma frames and components to HTML
- 📱 Responsive design with Bootstrap 5.3
- ♿ Semantic HTML output
- 🎯 Pixel-perfect styling
- 🔐 Secure API key management via config file
- 🚀 Simple command-line interface

## Prerequisites

- **Node.js 16+** - For the conversion utilities
- **bash** - For the main script
- **curl** - For API requests
- **jq** - For JSON parsing
- **Figma API Key** - Get it from [Figma Settings](https://www.figma.com/developers/api#authentication)

### Install Dependencies

**macOS (using Homebrew):**
```bash
brew install node jq curl
```

**Linux (Ubuntu/Debian):**
```bash
sudo apt-get install nodejs npm jq curl
```

## Setup

### 1. Get Your Figma API Key

1. Go to [https://www.figma.com/developers/api](https://www.figma.com/developers/api)
2. Log in or sign up
3. Create a new personal access token or use an existing one
4. Copy your API key

### 2. Get Your File ID

Open your Figma file in a browser. The URL will look like:
```
https://www.figma.com/file/YOUR_FILE_ID/file-name
```

Extract the `YOUR_FILE_ID` part.

### 3. Configure the Script

Copy the example config and add your API key:

```bash
cp .env.example .env
# Edit .env with your favorite editor and add:
# FIGMA_API_KEY=your_actual_api_key_here
```

### 4. Make the Script Executable

```bash
chmod +x figma-to-html.sh
```

## Usage

### Basic Usage

```bash
./figma-to-html.sh -f <FILE_ID> -p <PAGE_NAME> -c <COMPONENT_NAME>
```

### Examples

**Convert a button component:**
```bash
./figma-to-html.sh -f abc123def456 -p "Design" -c "Button"
```

**Convert a card component to a custom output directory:**
```bash
./figma-to-html.sh -f abc123def456 -p "Components" -c "Card" -o ./dist
```

**Get help:**
```bash
./figma-to-html.sh --help
```

## Command-Line Options

| Option | Alias | Description | Required |
|--------|-------|-------------|----------|
| `-f` | `--file-id` | Figma file ID | ✓ |
| `-p` | `--page` | Page name in Figma | ✓ |
| `-c` | `--component` | Frame or component name | ✓ |
| `-o` | `--output` | Output directory (default: `output`) | |
| `-h` | `--help` | Show help message | |

## Output

The script generates two files in the output directory:

### `index.html`
- Semantic HTML structure
- Bootstrap 5.3 CDN links
- Responsive meta tags
- Links to the generated CSS file

### `styles.css`
- Custom styles extracted from Figma
- Bootstrap utility classes
- Component-specific styling
- Comments indicating source

## Example Output

**index.html:**
```html
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Button</title>
    <link href="https://cdn.jsdelivr.net/npm/bootstrap@5.3.0/dist/css/bootstrap.min.css" rel="stylesheet">
    <link href="styles.css" rel="stylesheet">
</head>
<body>
    <div class="container-fluid p-4">
        <button class="btn btn-primary btn-1">Click Me</button>
    </div>
    <script src="https://cdn.jsdelivr.net/npm/bootstrap@5.3.0/dist/js/bootstrap.bundle.min.js"></script>
</body>
</html>
```

**styles.css:**
```css
/* Generated from Figma */
/* Bootstrap version: 5.3.0 */

.btn-1 {
  background-color: rgb(25, 118, 210);
  border-radius: 4px;
  padding: 8px 16px;
}
```

## Troubleshooting

### "Missing required dependencies"
Install the missing tools:
```bash
# macOS
brew install node jq curl

# Ubuntu/Debian
sudo apt-get install nodejs npm jq curl
```

### "Configuration file not found"
Create the `.env` file:
```bash
cp .env.example .env
# Edit .env and add your FIGMA_API_KEY
```

### "Page not found" or "Component not found"
- Verify the page name and component name are spelled exactly as they appear in Figma
- Check that the file ID is correct
- Ensure your API key has access to the file

### "Figma API error"
- Verify your API key is valid
- Check that your API key has permission to access the file
- Ensure the file is shared with your Figma account

## Configuration Options

### .env File

Create a `.env` file in the root directory with:

```bash
# Required
FIGMA_API_KEY=your_figma_api_key_here

# Optional (can be overridden via command line)
FIGMA_FILE_ID=your_figma_file_id_here
```

## How It Works

1. **Authentication**: Sends your API key to Figma's API
2. **File Fetch**: Retrieves the Figma file structure
3. **Page/Component Lookup**: Finds the specified page and component
4. **Data Extraction**: Fetches detailed node data from Figma
5. **Conversion**: Converts Figma properties to HTML and CSS:
   - **Layout**: Figma's auto-layout becomes flexbox
   - **Colors**: RGB values converted to CSS colors
   - **Typography**: Font properties preserved
   - **Spacing**: Converted to Bootstrap scales
   - **Shadows**: Drop shadows converted to CSS box-shadow
   - **Borders**: Stroke data converted to CSS borders
6. **Output**: Generates semantic HTML with Bootstrap integration

## Bootstrap Integration

The generated HTML uses Bootstrap 5.3 for:

- **Responsive Grid System**: Flexbox-based layout
- **Utility Classes**: Padding, margins, display
- **Components**: Buttons, cards, alerts, modals
- **Typography**: Heading and text styles
- **Spacing Scale**: Consistent margin/padding sizing
- **CDN Delivery**: Latest Bootstrap via jsDelivr CDN

## Limitations

- Complex interactions and animations are not converted
- Custom Figma plugins and advanced effects may not translate
- Prototype links and interactions are not preserved
- Some advanced CSS features may require manual adjustment
- Very complex nested components may need refinement

## Tips for Best Results

1. **Use Bootstrap Components**: Build your Figma components using Bootstrap design patterns
2. **Consistent Naming**: Use clear, consistent names for pages, frames, and components
3. **Test Responsiveness**: The generated HTML may need responsive adjustments
4. **Validate HTML**: Always validate the generated HTML for accessibility
5. **Custom CSS**: Add custom CSS as needed for pixel-perfect results

## API Rate Limiting

Figma API has rate limits. Check the API documentation for current limits. The script respects these limits automatically.

## License

MIT

## Support

For issues, feature requests, or contributions, please refer to the project repository.

## Contributing

Contributions are welcome! Please ensure:

- Bash scripts pass `shellcheck`
- JavaScript code is well-commented
- Changes maintain backward compatibility
- New features include documentation

## Future Enhancements

- [ ] Support for nested components
- [ ] Animation/transition support
- [ ] Advanced shadow and filter effects
- [ ] Figma variable support
- [ ] CSS-in-JS output option
- [ ] React/Vue component generation
- [ ] Theme customization
- [ ] Batch conversion support

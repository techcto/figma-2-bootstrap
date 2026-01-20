#!/usr/bin/env node

/**
 * Figma Frame to HTML/CSS Converter
 * Converts Figma node data to semantic HTML and Bootstrap-styled CSS
 */

const fs = require('fs');
const path = require('path');

// Parse command line arguments
const args = process.argv.slice(2);
let inputFile = '';
let outputDir = '';
let componentName = '';
let outputFile = 'index.html';

for (let i = 0; i < args.length; i++) {
    switch (args[i]) {
        case '--input':
            inputFile = args[++i];
            break;
        case '--output':
            outputDir = args[++i];
            break;
        case '--component':
            componentName = args[++i];
            break;
        case '--output-file':
            outputFile = args[++i];
            break;
    }
}

if (!inputFile || !outputDir) {
    console.error('Usage: converter.js --input <file> --output <dir> --component <name>');
    process.exit(1);
}

// Bootstrap 5 version
const BOOTSTRAP_VERSION = '5.3.0';
const BOOTSTRAP_CDN = `https://cdn.jsdelivr.net/npm/bootstrap@${BOOTSTRAP_VERSION}/dist`;

// Bootstrap spacing scale (in pixels)
const BOOTSTRAP_SCALE = {
    0: 0,
    1: 4,
    2: 8,
    3: 12,
    4: 16,
    5: 24,
};

/**
 * Parse Figma data and convert to HTML/CSS
 */
class FigmaConverter {
    constructor() {
        this.styles = {};
        this.html = '';
        this.classCounter = 0;
        this.components = [];
    }

    /**
     * Load and parse Figma data
     */
    loadFigmaData(filePath) {
        try {
            const data = fs.readFileSync(filePath, 'utf8');
            return JSON.parse(data);
        } catch (error) {
            console.error(`Failed to load Figma data: ${error.message}`);
            process.exit(1);
        }
    }

    /**
     * Extract relevant node from Figma data structure
     */
    findMainNode(data) {
        if (data.nodes) {
            const nodeIds = Object.keys(data.nodes);
            if (nodeIds.length > 0) {
                return data.nodes[nodeIds[0]];
            }
        }
        return null;
    }

    /**
     * Convert color to CSS hex
     */
    colorToCss(color) {
        if (!color) return 'transparent';
        if (color.r !== undefined && color.g !== undefined && color.b !== undefined) {
            const r = Math.round(color.r * 255);
            const g = Math.round(color.g * 255);
            const b = Math.round(color.b * 255);
            const a = color.a !== undefined ? color.a : 1;
            if (a < 1) {
                return `rgba(${r}, ${g}, ${b}, ${a})`;
            }
            return `rgb(${r}, ${g}, ${b})`;
        }
        return 'transparent';
    }

    /**
     * Find closest Bootstrap spacing value
     */
    findClosestBootstrapScale(pixels) {
        if (!pixels) return 0;
        const px = Math.round(pixels);
        let closest = 0;
        let closestDiff = Math.abs(px - BOOTSTRAP_SCALE[0]);

        for (const [scale, value] of Object.entries(BOOTSTRAP_SCALE)) {
            const diff = Math.abs(px - value);
            if (diff < closestDiff) {
                closestDiff = diff;
                closest = scale;
            }
        }

        return closest;
    }

    /**
     * Get Bootstrap utility classes for padding and spacing
     */
    getBootstrapSpacingClasses(node) {
        const classes = [];

        if (!node) return classes;

        // Handle padding
        if (node.paddingLeft || node.paddingRight || node.paddingTop || node.paddingBottom) {
            // Symmetric padding
            if (node.paddingLeft === node.paddingRight && node.paddingTop === node.paddingBottom) {
                const hScale = this.findClosestBootstrapScale(node.paddingLeft);
                const vScale = this.findClosestBootstrapScale(node.paddingTop);

                if (hScale === vScale) {
                    classes.push(`p-${hScale}`);
                } else {
                    if (hScale) classes.push(`px-${hScale}`);
                    if (vScale) classes.push(`py-${vScale}`);
                }
            } else {
                // Individual padding
                if (node.paddingLeft) classes.push(`ps-${this.findClosestBootstrapScale(node.paddingLeft)}`);
                if (node.paddingRight) classes.push(`pe-${this.findClosestBootstrapScale(node.paddingRight)}`);
                if (node.paddingTop) classes.push(`pt-${this.findClosestBootstrapScale(node.paddingTop)}`);
                if (node.paddingBottom) classes.push(`pb-${this.findClosestBootstrapScale(node.paddingBottom)}`);
            }
        }

        // Handle gaps (spacing between items in flex containers)
        if (node.itemSpacing) {
            const gapScale = this.findClosestBootstrapScale(node.itemSpacing);
            if (gapScale) {
                classes.push(`gap-${gapScale}`);
            }
        }

        return classes;
    }

    /**
     * Convert Figma fills to CSS
     */
    extractFill(paint) {
        if (!paint || paint.type !== 'SOLID') {
            return null;
        }
        return this.colorToCss(paint.color);
    }

    /**
     * Extract typography styles
     */
    extractTypography(node) {
        const styles = {};
        
        if (node.style) {
            if (node.style.fontSize) {
                styles.fontSize = `${node.style.fontSize}px`;
            }
            if (node.style.fontWeight) {
                styles.fontWeight = node.style.fontWeight;
            }
            if (node.style.lineHeightPx) {
                styles.lineHeight = `${node.style.lineHeightPx}px`;
            }
            if (node.style.letterSpacing) {
                styles.letterSpacing = `${node.style.letterSpacing}px`;
            }
            if (node.style.textAlignHorizontal) {
                const alignment = {
                    'LEFT': 'left',
                    'CENTER': 'center',
                    'RIGHT': 'right',
                    'JUSTIFIED': 'justify'
                };
                styles.textAlign = alignment[node.style.textAlignHorizontal] || 'left';
            }
        }

        return styles;
    }

    /**
     * Generate unique class name
     */
    generateClassName(baseName = 'element') {
        return `${baseName}-${++this.classCounter}`;
    }

    /**
     * Scan for components within a frame
     */
    scanForComponents(node) {
        const components = [];

        if (!node || !node.children) return components;

        for (const child of node.children) {
            if (child.type === 'COMPONENT' || child.type === 'INSTANCE' || child.type === 'FRAME') {
                components.push(child);
            }
            // Recursively scan nested frames
            if (child.type === 'FRAME' || child.type === 'GROUP') {
                components.push(...this.scanForComponents(child));
            }
        }

        return components;
    }

    /**
     * Convert a single Figma node to HTML
     */
    nodeToHtml(node, depth = 0) {
        if (!node) return '';

        const indent = '  '.repeat(depth);
        let html = '';

        // Handle text nodes
        if (node.type === 'TEXT') {
            const content = node.characters || '';
            const className = this.generateClassName('text');
            const styles = this.extractTypography(node);

            // Store styles
            this.addStyleRule(className, styles);

            // Determine semantic tag
            let tag = 'p';
            if (node.style?.fontSize > 24) {
                tag = 'h1';
            } else if (node.style?.fontSize > 20) {
                tag = 'h2';
            } else if (node.style?.fontSize > 16) {
                tag = 'h3';
            }

            html += `${indent}<${tag} class="${className}">${this.escapeHtml(content)}</${tag}>\n`;
        }
        // Handle rectangles, frames, groups, components, and instances
        else if (node.type === 'RECTANGLE' || node.type === 'FRAME' || node.type === 'GROUP' || node.type === 'COMPONENT' || node.type === 'INSTANCE') {
            const className = this.generateClassName(node.type.toLowerCase());
            const styles = this.extractNodeStyles(node);
            const bootstrapSpacingClasses = this.getBootstrapSpacingClasses(node);
            const bootstrapFlexClasses = this.getBootstrapFlexClasses(node);

            this.addStyleRule(className, styles);

            const tag = (node.type === 'FRAME' || node.type === 'COMPONENT') ? 'section' : 'div';
            const allClasses = [className, ...bootstrapSpacingClasses, ...bootstrapFlexClasses].filter(Boolean).join(' ');

            html += `${indent}<${tag} class="${allClasses}"`; 

            html += `>\n`;

            // Recursively process children
            if (node.children && Array.isArray(node.children)) {
                for (const child of node.children) {
                    html += this.nodeToHtml(child, depth + 1);
                }
            }

            html += `${indent}</${tag}>\n`;
        }
        // Handle buttons
        else if (node.type === 'INSTANCE' || (node.name && node.name.toLowerCase().includes('button'))) {
            const content = node.characters || (node.name || 'Button');
            const className = this.generateClassName('btn');
            const styles = this.extractNodeStyles(node);
            const bootstrapClasses = this.getBootstrapSpacingClasses(node);

            this.addStyleRule(className, styles);

            const allClasses = ['btn', 'btn-primary', className, ...bootstrapClasses].filter(Boolean).join(' ');
            html += `${indent}<button class="${allClasses}">${this.escapeHtml(content)}</button>\n`;
        }
        // Handle images
        else if (node.type === 'IMAGE') {
            const className = this.generateClassName('img');
            const styles = this.extractNodeStyles(node);
            const bootstrapClasses = this.getBootstrapSpacingClasses(node);

            this.addStyleRule(className, styles);

            const allClasses = [className, 'img-fluid', ...bootstrapClasses].filter(Boolean).join(' ');
            html += `${indent}<img class="${allClasses}" alt="${this.escapeHtml(node.name || 'image')}" />\n`;
        }
        // Default container
        else {
            const className = this.generateClassName('container');
            const styles = this.extractNodeStyles(node);
            const bootstrapClasses = this.getBootstrapSpacingClasses(node);

            this.addStyleRule(className, styles);

            const allClasses = [className, ...bootstrapClasses].filter(Boolean).join(' ');
            html += `${indent}<div class="${allClasses}">\n`;

            if (node.children && Array.isArray(node.children)) {
                for (const child of node.children) {
                    html += this.nodeToHtml(child, depth + 1);
                }
            }

            html += `${indent}</div>\n`;
        }

        return html;
    }

    /**
     * Extract CSS styles from a node
     */
    extractNodeStyles(node) {
        const styles = {};

        // Background color
        if (node.fills && node.fills.length > 0) {
            const fill = this.extractFill(node.fills[0]);
            if (fill) {
                styles.backgroundColor = fill;
            }
        }

        // Stroke/Border
        if (node.strokes && node.strokes.length > 0) {
            const stroke = this.extractFill(node.strokes[0]);
            if (stroke && node.strokeWeight) {
                styles.border = `${node.strokeWeight}px solid ${stroke}`;
            }
        }

        // Shadow
        if (node.effects && node.effects.length > 0) {
            const shadows = node.effects
                .filter(e => e.type === 'DROP_SHADOW' && e.visible !== false)
                .map(e => {
                    const offsetX = e.offset?.x || 0;
                    const offsetY = e.offset?.y || 0;
                    const blur = e.blur?.value || 0;
                    const spread = e.spread || 0;
                    const color = this.colorToCss(e.color);
                    return `${offsetX}px ${offsetY}px ${blur}px ${spread}px ${color}`;
                });
            if (shadows.length > 0) {
                styles.boxShadow = shadows.join(', ');
            }
        }

        // Border radius
        if (node.cornerRadius) {
            styles.borderRadius = `${node.cornerRadius}px`;
        }

        // Display and layout - Only apply flexbox CSS if explicitly needed
        // Note: Bootstrap classes will handle flex display in HTML
        if (node.layoutMode === 'HORIZONTAL' || node.layoutMode === 'VERTICAL') {
            // Don't add flex styles here - they'll be added via Bootstrap classes
            // Just track that this node has auto-layout for the class generator
        }

        // Add width and height if specified
        if (node.width) {
            styles.width = `${node.width}px`;
        }
        if (node.height) {
            styles.height = `${node.height}px`;
        }

        return styles;
    }

    /**
     * Get Bootstrap flexbox classes for auto-layout
     */
    getBootstrapFlexClasses(node) {
        const classes = [];

        if (!node || !node.layoutMode) return classes;

        // Add flex display
        classes.push('d-flex');

        // Add flex direction
        if (node.layoutMode === 'HORIZONTAL') {
            classes.push('flex-row');
        } else if (node.layoutMode === 'VERTICAL') {
            classes.push('flex-column');
        }

        // Add primary axis alignment (justify-content)
        if (node.primaryAxisAlignItems) {
            const alignment = {
                'MIN': 'justify-content-start',
                'CENTER': 'justify-content-center',
                'MAX': 'justify-content-end',
                'SPACE_BETWEEN': 'justify-content-between',
                'SPACE_AROUND': 'justify-content-around',
                'SPACE_EVENLY': 'justify-content-evenly'
            };
            if (alignment[node.primaryAxisAlignItems]) {
                classes.push(alignment[node.primaryAxisAlignItems]);
            }
        }

        // Add counter axis alignment (align-items)
        if (node.counterAxisAlignItems) {
            const alignment = {
                'MIN': 'align-items-start',
                'CENTER': 'align-items-center',
                'MAX': 'align-items-end',
                'STRETCH': 'align-items-stretch'
            };
            if (alignment[node.counterAxisAlignItems]) {
                classes.push(alignment[node.counterAxisAlignItems]);
            }
        }

        // Add gap (item spacing)
        if (node.itemSpacing) {
            const gapScale = this.findClosestBootstrapScale(node.itemSpacing);
            if (gapScale) {
                classes.push(`gap-${gapScale}`);
            }
        }

        return classes;
    }

    /**
     * Add a CSS style rule
     */
    addStyleRule(className, styles) {
        if (Object.keys(styles).length === 0) return;

        const cssRule = Object.entries(styles)
            .map(([key, value]) => {
                const cssKey = key.replace(/([A-Z])/g, '-$1').toLowerCase();
                return `  ${cssKey}: ${value};`;
            })
            .join('\n');

        this.styles[className] = `\n.${className} {\n${cssRule}\n}\n`;
    }

    /**
     * Escape HTML special characters
     */
    escapeHtml(text) {
        const map = {
            '&': '&amp;',
            '<': '&lt;',
            '>': '&gt;',
            '"': '&quot;',
            "'": '&#039;'
        };
        return text.replace(/[&<>"']/g, m => map[m]);
    }

    /**
     * Generate complete HTML document with components
     */
    generateHtmlDocument(title = 'Figma Design', isChildFile = false) {
        const cssPath = isChildFile ? '../styles.css' : 'styles.css';
        return `<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>${this.escapeHtml(title)}</title>
    
    <!-- Bootstrap CSS -->
    <link href="${BOOTSTRAP_CDN}/css/bootstrap.min.css" rel="stylesheet">
    
    <!-- Custom Styles -->
    <link href="${cssPath}" rel="stylesheet">
</head>
<body>
    <div class="container-fluid p-4">
${this.html}    </div>

    <!-- Bootstrap JS Bundle -->
    <script src="${BOOTSTRAP_CDN}/js/bootstrap.bundle.min.js"></script>
</body>
</html>
`;
    }

    /**
     * Generate CSS file content
     */
    generateCss() {
        let css = '/* Generated from Figma */\n';
        css += '/* Bootstrap version: 5.3.0 */\n';
        css += '/* Spacing uses Bootstrap utility classes */\n\n';
        css += Object.values(this.styles).join('\n');
        return css;
    }

    /**
     * Convert and save files
     */
    convert(filePath, outputDir, componentName, outputFile = 'index.html') {
        console.log('Loading Figma data...');
        const figmaData = this.loadFigmaData(filePath);

        console.log('Finding main node...');
        const mainNode = this.findMainNode(figmaData);
        if (!mainNode) {
            console.error('No node data found in Figma file');
            process.exit(1);
        }

        console.log('Scanning for components...');
        this.components = this.scanForComponents(mainNode.document || mainNode);
        if (this.components.length > 0) {
            console.log(`Found ${this.components.length} component(s)`);
        }

        console.log('Converting to HTML...');
        this.html = this.nodeToHtml(mainNode.document || mainNode, 2);

        // Create output directory if it doesn't exist
        if (!fs.existsSync(outputDir)) {
            fs.mkdirSync(outputDir, { recursive: true });
        }

        // Write HTML file
        const htmlPath = path.join(outputDir, outputFile);
        const isChildFile = outputFile !== 'index.html';
        const htmlContent = this.generateHtmlDocument(componentName, isChildFile);
        fs.writeFileSync(htmlPath, htmlContent, 'utf8');
        console.log(`HTML saved to: ${htmlPath}`);

        // Write CSS file (only if output file is index.html)
        if (outputFile === 'index.html') {
            const cssPath = path.join(outputDir, 'styles.css');
            const cssContent = this.generateCss();
            fs.writeFileSync(cssPath, cssContent, 'utf8');
            console.log(`CSS saved to: ${cssPath}`);

            // Write component metadata
            if (this.components.length > 0) {
                const metaPath = path.join(outputDir, 'components.json');
                const componentMeta = this.components.map(c => ({
                    name: c.name,
                    type: c.type,
                    id: c.id
                }));
                fs.writeFileSync(metaPath, JSON.stringify(componentMeta, null, 2), 'utf8');
                console.log(`Component metadata saved to: ${metaPath}`);
            }
        }
    }
}

// Run conversion
const converter = new FigmaConverter();
converter.convert(inputFile, outputDir, componentName, outputFile);

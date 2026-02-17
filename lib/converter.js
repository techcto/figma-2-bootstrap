#!/usr/bin/env node

/**
 * Figma Frame to Bootstrap HTML Converter
 * Converts Figma node data to semantic HTML with Bootstrap utilities only
 * No custom CSS is generated
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

// Bootstrap 5 configuration
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

// Bootstrap color palette (default theme colors)
const BOOTSTRAP_COLORS = {
    'primary': '#0d6efd',
    'secondary': '#6c757d',
    'success': '#198754',
    'danger': '#dc3545',
    'warning': '#ffc107',
    'info': '#0dcaf0',
    'light': '#f8f9fa',
    'dark': '#212529',
    'white': '#ffffff',
    'black': '#000000',
};

/**
 * Parse Figma data and convert to HTML with Bootstrap utilities
 */
class FigmaConverter {
    constructor() {
        this.html = '';
        this.components = [];
        this.variables = {};
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
     * Extract variables from Figma data
     */
    extractVariables(data) {
        if (data.variables) {
            for (const varId in data.variables) {
                const variable = data.variables[varId];
                if (variable.valuesByMode) {
                    for (const modeId in variable.valuesByMode) {
                        const value = variable.valuesByMode[modeId];
                        if (variable.resolvedType === 'COLOR') {
                            this.variables[varId] = value;
                        }
                        break;
                    }
                } else if (typeof variable === 'object' && variable.r !== undefined) {
                    this.variables[varId] = this.colorToCss(variable);
                } else if (typeof variable === 'string') {
                    this.variables[varId] = variable;
                }
            }
        }
    }

    /**
     * Resolve a variable to its color value
     */
    resolveVariable(varId) {
        if (!varId || !this.variables[varId]) return null;
        const value = this.variables[varId];
        
        if (typeof value === 'string') {
            return value;
        } else if (value.r !== undefined) {
            return this.colorToCss(value);
        }
        return null;
    }

    /**
     * Convert color object to CSS hex/rgb string
     */
    colorToCss(color) {
        if (!color) return null;
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
        return null;
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
                closest = parseInt(scale);
            }
        }

        return closest;
    }

    /**
     * Find closest Bootstrap color by RGB distance
     */
    findClosestBootstrapColor(colorString) {
        if (!colorString) return null;

        // Extract RGB values
        let r, g, b;
        
        if (colorString.startsWith('rgb')) {
            const match = colorString.match(/\d+/g);
            if (match && match.length >= 3) {
                [r, g, b] = match.slice(0, 3).map(Number);
            }
        } else if (colorString.startsWith('#')) {
            const hex = colorString.slice(1);
            r = parseInt(hex.slice(0, 2), 16);
            g = parseInt(hex.slice(2, 4), 16);
            b = parseInt(hex.slice(4, 6), 16);
        }

        if (r === undefined || g === undefined || b === undefined) {
            return null;
        }

        // Find closest Bootstrap color
        let closestColor = null;
        let minDistance = Infinity;

        for (const [colorName, colorHex] of Object.entries(BOOTSTRAP_COLORS)) {
            const hexColor = colorHex.slice(1);
            const cr = parseInt(hexColor.slice(0, 2), 16);
            const cg = parseInt(hexColor.slice(2, 4), 16);
            const cb = parseInt(hexColor.slice(4, 6), 16);

            const distance = Math.sqrt(
                Math.pow(r - cr, 2) +
                Math.pow(g - cg, 2) +
                Math.pow(b - cb, 2)
            );

            if (distance < minDistance) {
                minDistance = distance;
                closestColor = colorName;
            }
        }

        return closestColor;
    }

    /**
     * Get the first visible solid fill from an array of fills
     */
    getFirstVisibleFill(fills) {
        if (!fills || fills.length === 0) return null;
        
        for (const fill of fills) {
            if (fill.type === 'SOLID' && fill.visible !== false) {
                if (fill.boundVariables && fill.boundVariables.color) {
                    const resolvedColor = this.resolveVariable(fill.boundVariables.color);
                    if (resolvedColor) return resolvedColor;
                }
                if (fill.color) {
                    return this.colorToCss(fill.color);
                }
            }
        }
        
        for (const fill of fills) {
            if (fill.type === 'SOLID') {
                if (fill.boundVariables && fill.boundVariables.color) {
                    const resolvedColor = this.resolveVariable(fill.boundVariables.color);
                    if (resolvedColor) return resolvedColor;
                }
                if (fill.color) {
                    return this.colorToCss(fill.color);
                }
            }
        }
        
        return null;
    }

    /**
     * Get Bootstrap utility classes for background color
     */
    getBackgroundColorClass(fills) {
        const fillColor = this.getFirstVisibleFill(fills);
        if (!fillColor) return null;

        const closestColor = this.findClosestBootstrapColor(fillColor);
        return closestColor ? `bg-${closestColor}` : null;
    }

    /**
     * Get Bootstrap utility classes for text color
     */
    getTextColorClass(fills) {
        const fillColor = this.getFirstVisibleFill(fills);
        if (!fillColor) return null;

        const closestColor = this.findClosestBootstrapColor(fillColor);
        return closestColor ? `text-${closestColor}` : null;
    }

    /**
     * Get Bootstrap typography classes
     */
    getTypographyClasses(node) {
        const classes = [];

        if (!node.style) return classes;

        // Font size to Bootstrap fs-* scale
        if (node.style.fontSize) {
            const size = node.style.fontSize;
            let fsClass = null;
            
            if (size <= 14) fsClass = 'fs-6';
            else if (size <= 16) fsClass = 'fs-6';
            else if (size <= 20) fsClass = 'fs-5';
            else if (size <= 24) fsClass = 'fs-4';
            else if (size <= 28) fsClass = 'fs-3';
            else if (size <= 32) fsClass = 'fs-2';
            else fsClass = 'fs-1';

            if (fsClass) classes.push(fsClass);
        }

        // Font weight to Bootstrap fw-* classes
        if (node.style.fontWeight) {
            const weight = node.style.fontWeight;
            if (weight >= 700) classes.push('fw-bold');
            else if (weight >= 600) classes.push('fw-semibold');
            else if (weight <= 400) classes.push('fw-normal');
        }

        // Text alignment
        if (node.style.textAlignHorizontal) {
            const alignment = {
                'LEFT': 'text-start',
                'CENTER': 'text-center',
                'RIGHT': 'text-end',
                'JUSTIFIED': 'text-justify'
            };
            const alignClass = alignment[node.style.textAlignHorizontal];
            if (alignClass) classes.push(alignClass);
        }

        // Text color
        if (node.fills && node.fills.length > 0) {
            const textColorClass = this.getTextColorClass(node.fills);
            if (textColorClass) classes.push(textColorClass);
        }

        return classes;
    }

    /**
     * Get Bootstrap spacing classes for padding
     */
    getBootstrapSpacingClasses(node) {
        const classes = [];

        if (!node) return classes;

        // Handle padding
        if (node.paddingLeft || node.paddingRight || node.paddingTop || node.paddingBottom) {
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
                if (node.paddingLeft) classes.push(`ps-${this.findClosestBootstrapScale(node.paddingLeft)}`);
                if (node.paddingRight) classes.push(`pe-${this.findClosestBootstrapScale(node.paddingRight)}`);
                if (node.paddingTop) classes.push(`pt-${this.findClosestBootstrapScale(node.paddingTop)}`);
                if (node.paddingBottom) classes.push(`pb-${this.findClosestBootstrapScale(node.paddingBottom)}`);
            }
        }

        // Handle itemSpacing (gap)
        if (node.itemSpacing) {
            const gapScale = this.findClosestBootstrapScale(node.itemSpacing);
            if (gapScale) classes.push(`gap-${gapScale}`);
        }

        return classes;
    }

    /**
     * Get Bootstrap flexbox classes for auto-layout
     */
    getBootstrapFlexClasses(node) {
        const classes = [];

        if (!node || !node.layoutMode) return classes;

        classes.push('d-flex');

        if (node.layoutMode === 'HORIZONTAL') {
            classes.push('flex-row');
        } else if (node.layoutMode === 'VERTICAL') {
            classes.push('flex-column');
        }

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

        return classes;
    }

    /**
     * Get Bootstrap size utility classes
     */
    getBootstrapSizeClasses(node) {
        const classes = [];

        if (!node) return classes;

        // Width - Bootstrap provides w-25, w-50, w-75, w-100, w-auto
        if (node.width) {
            // Map pixel widths to Bootstrap classes if possible
            // Otherwise skip (no custom CSS allowed)
            const widthPercent = (node.width / node.parent?.width) * 100 || null;
            if (widthPercent === 100) classes.push('w-100');
            else if (widthPercent === 75) classes.push('w-75');
            else if (widthPercent === 50) classes.push('w-50');
            else if (widthPercent === 25) classes.push('w-25');
        }

        return classes;
    }

    /**
     * Get Bootstrap border classes
     */
    getBootstrapBorderClasses(node) {
        const classes = [];

        if (!node) return classes;

        // Border - only if strokes exist
        if (node.strokes && node.strokes.length > 0) {
            classes.push('border');
            
            // Corner radius
            if (node.cornerRadius) {
                if (node.cornerRadius < 4) {
                    classes.push('rounded-0');
                } else if (node.cornerRadius < 8) {
                    classes.push('rounded-1');
                } else if (node.cornerRadius < 12) {
                    classes.push('rounded-2');
                } else {
                    classes.push('rounded-3');
                }
            }
        }

        // Shadow - Bootstrap has shadow, shadow-sm, shadow-lg
        if (node.effects && node.effects.length > 0) {
            const hasShadow = node.effects.some(e => e.type === 'DROP_SHADOW' && e.visible !== false);
            if (hasShadow) {
                classes.push('shadow');
            }
        }

        return classes;
    }

    /**
     * Scan for components within a node
     */
    scanForComponents(node) {
        const components = [];

        if (!node || !node.children) return components;

        for (const child of node.children) {
            if (child.type === 'COMPONENT' || child.type === 'INSTANCE' || child.type === 'FRAME') {
                components.push(child);
            }
            if (child.type === 'FRAME' || child.type === 'GROUP') {
                components.push(...this.scanForComponents(child));
            }
        }

        return components;
    }

    /**
     * Convert a single Figma node to HTML with Bootstrap classes only
     */
    nodeToHtml(node, depth = 0) {
        if (!node) return '';

        const indent = '  '.repeat(depth);
        let html = '';

        // Handle text nodes
        if (node.type === 'TEXT') {
            const content = node.characters || '';
            const typographyClasses = this.getTypographyClasses(node);

            // Determine semantic tag based on font size
            let tag = 'p';
            if (node.style?.fontSize > 24) {
                tag = 'h1';
            } else if (node.style?.fontSize > 20) {
                tag = 'h2';
            } else if (node.style?.fontSize > 16) {
                tag = 'h3';
            }

            const allClasses = typographyClasses.filter(Boolean).join(' ');
            const classAttr = allClasses ? ` class="${allClasses}"` : '';

            html += `${indent}<${tag}${classAttr}>${this.escapeHtml(content)}</${tag}>\n`;
        }
        // Handle rectangles, frames, groups, components
        else if (node.type === 'RECTANGLE' || node.type === 'FRAME' || node.type === 'GROUP' || 
                 node.type === 'COMPONENT' || node.type === 'INSTANCE') {
            
            const bootstrapSpacingClasses = this.getBootstrapSpacingClasses(node);
            const bootstrapFlexClasses = this.getBootstrapFlexClasses(node);
            const bootstrapSizeClasses = this.getBootstrapSizeClasses(node);
            const bootstrapBorderClasses = this.getBootstrapBorderClasses(node);
            const bgColorClass = this.getBackgroundColorClass(node.fills);

            const tag = (node.type === 'FRAME' || node.type === 'COMPONENT') ? 'section' : 'div';
            const allClasses = [
                ...bootstrapSpacingClasses,
                ...bootstrapFlexClasses,
                ...bootstrapSizeClasses,
                ...bootstrapBorderClasses,
                bgColorClass
            ].filter(Boolean).join(' ');

            const classAttr = allClasses ? ` class="${allClasses}"` : '';

            html += `${indent}<${tag}${classAttr}>\n`;

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
            const bootstrapSpacingClasses = this.getBootstrapSpacingClasses(node);
            const bgColorClass = this.getBackgroundColorClass(node.fills) || 'btn-primary';

            const allClasses = ['btn', bgColorClass, ...bootstrapSpacingClasses]
                .filter(Boolean)
                .join(' ');

            html += `${indent}<button class="${allClasses}">${this.escapeHtml(content)}</button>\n`;
        }
        // Handle images
        else if (node.type === 'IMAGE') {
            const bootstrapSpacingClasses = this.getBootstrapSpacingClasses(node);
            const allClasses = ['img-fluid', ...bootstrapSpacingClasses].filter(Boolean).join(' ');
            const classAttr = allClasses ? ` class="${allClasses}"` : '';

            html += `${indent}<img${classAttr} alt="${this.escapeHtml(node.name || 'image')}" />\n`;
        }
        // Default container
        else {
            const bootstrapSpacingClasses = this.getBootstrapSpacingClasses(node);
            const bootstrapFlexClasses = this.getBootstrapFlexClasses(node);
            const bgColorClass = this.getBackgroundColorClass(node.fills);

            const allClasses = [
                ...bootstrapSpacingClasses,
                ...bootstrapFlexClasses,
                bgColorClass
            ].filter(Boolean).join(' ');

            const classAttr = allClasses ? ` class="${allClasses}"` : '';

            html += `${indent}<div${classAttr}>\n`;

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
     * Generate complete HTML document with Bootstrap only
     */
    generateHtmlDocument(title = 'Figma Design') {
        return `<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>${this.escapeHtml(title)}</title>
    
    <!-- Bootstrap CSS -->
    <link href="${BOOTSTRAP_CDN}/css/bootstrap.min.css" rel="stylesheet">
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
     * Convert and save files
     */
    convert(filePath, outputDir, componentName, outputFile = 'index.html') {
        console.log('Loading Figma data...');
        const figmaData = this.loadFigmaData(filePath);

        console.log('Extracting variables...');
        this.extractVariables(figmaData);

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
        const htmlContent = this.generateHtmlDocument(componentName);
        fs.writeFileSync(htmlPath, htmlContent, 'utf8');
        console.log(`HTML saved to: ${htmlPath}`);

        // Write component metadata
        if (outputFile === 'index.html') {
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

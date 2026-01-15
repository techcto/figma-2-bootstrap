#!/bin/bash

# Figma to Bootstrap Components Converter
# This script extracts components from a Figma page and creates individual HTML and TPL files

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Check for required dependencies
check_dependencies() {
    local missing_deps=()
    
    command -v curl >/dev/null 2>&1 || missing_deps+=("curl")
    command -v jq >/dev/null 2>&1 || missing_deps+=("jq")
    
    if [ ${#missing_deps[@]} -ne 0 ]; then
        echo -e "${RED}Error: Missing required dependencies: ${missing_deps[*]}${NC}"
        echo "Install them with: sudo apt-get install ${missing_deps[*]}"
        exit 1
    fi
}

# Display usage information
usage() {
    cat << EOF
Usage: $0 [OPTIONS]

Convert Figma components to HTML/TPL files with Bootstrap

Required:
    -k, --api-key KEY       Figma API key (or set FIGMA_API_KEY env var)
    -f, --file-id ID        Figma file ID
    -p, --page-names NAMES  Comma-separated page names (e.g., "Components,Forms,Layouts")
                           Or use multiple -p flags: -p "Components" -p "Forms"

Optional:
    -o, --output-dir DIR    Output directory (default: ./figma-components)
    -b, --bootstrap VER     Bootstrap version (default: 5.3.2)
    -t, --template-engine   Template engine for .tpl files (default: smarty)
    -s, --shared-only      Only extract components that appear on multiple pages
    -h, --help             Show this help message

Examples:
    # Single page
    $0 -k YOUR_API_KEY -f FILE_ID -p "Components" -o ./output
    
    # Multiple pages (comma-separated)
    $0 -k YOUR_API_KEY -f FILE_ID -p "Components,Forms,Layouts" -o ./output
    
    # Multiple pages (multiple flags)
    $0 -k YOUR_API_KEY -f FILE_ID -p "Components" -p "Forms" -p "Layouts"
    
    # Extract only shared components
    $0 -k YOUR_API_KEY -f FILE_ID -p "Page1,Page2" -s

Environment Variables:
    FIGMA_API_KEY          Figma API key (alternative to -k flag)

EOF
    exit 1
}

# Parse command line arguments
parse_args() {
    FIGMA_API_KEY="${FIGMA_API_KEY:-}"
    FILE_ID=""
    PAGE_NAMES=()
    OUTPUT_DIR="./figma-components"
    BOOTSTRAP_VERSION="5.3.2"
    TEMPLATE_ENGINE="smarty"
    SHARED_ONLY=false
    
    while [[ $# -gt 0 ]]; do
        case $1 in
            -k|--api-key)
                FIGMA_API_KEY="$2"
                shift 2
                ;;
            -f|--file-id)
                FILE_ID="$2"
                shift 2
                ;;
            -p|--page-names|--page-name)
                # Support both comma-separated and multiple flags
                IFS=',' read -ra PAGES <<< "$2"
                for page in "${PAGES[@]}"; do
                    # Trim whitespace
                    page=$(echo "$page" | xargs)
                    if [ ! -z "$page" ]; then
                        PAGE_NAMES+=("$page")
                    fi
                done
                shift 2
                ;;
            -o|--output-dir)
                OUTPUT_DIR="$2"
                shift 2
                ;;
            -b|--bootstrap)
                BOOTSTRAP_VERSION="$2"
                shift 2
                ;;
            -t|--template-engine)
                TEMPLATE_ENGINE="$2"
                shift 2
                ;;
            -s|--shared-only)
                SHARED_ONLY=true
                shift
                ;;
            -h|--help)
                usage
                ;;
            *)
                echo -e "${RED}Unknown option: $1${NC}"
                usage
                ;;
        esac
    done
    
    # Validate required parameters
    if [ -z "$FIGMA_API_KEY" ]; then
        echo -e "${RED}Error: Figma API key is required${NC}"
        usage
    fi
    
    if [ -z "$FILE_ID" ]; then
        echo -e "${RED}Error: Figma file ID is required${NC}"
        usage
    fi
    
    if [ ${#PAGE_NAMES[@]} -eq 0 ]; then
        echo -e "${RED}Error: At least one page name is required${NC}"
        usage
    fi
}

# Fetch Figma file data
fetch_figma_data() {
    echo -e "${YELLOW}Fetching Figma file data...${NC}"
    
    local response=$(curl -s -H "X-Figma-Token: $FIGMA_API_KEY" \
        "https://api.figma.com/v1/files/$FILE_ID")
    
    if echo "$response" | jq -e '.err' > /dev/null 2>&1; then
        echo -e "${RED}Error fetching Figma data: $(echo "$response" | jq -r '.err')${NC}"
        exit 1
    fi
    
    echo "$response" > "$OUTPUT_DIR/figma-data.json"
    echo -e "${GREEN}✓ Figma data fetched successfully${NC}"
}

# Extract components from the specified pages
extract_components() {
    echo -e "${YELLOW}Extracting components from ${#PAGE_NAMES[@]} page(s)...${NC}"
    
    local figma_data="$OUTPUT_DIR/figma-data.json"
    local all_components_file="$OUTPUT_DIR/all-components.json"
    
    # Initialize arrays to track components
    declare -A component_map
    declare -A component_pages
    
    # Extract components from each page
    for page_name in "${PAGE_NAMES[@]}"; do
        echo -e "  Processing page: ${GREEN}$page_name${NC}"
        
        local page_components=$(jq -r --arg page "$page_name" '
            .document.children[] | 
            select(.name == $page) | 
            .. | 
            select(.type? == "COMPONENT") | 
            {
                id: .id,
                name: .name,
                type: .type,
                bounds: .absoluteBoundingBox,
                children: .children,
                page: $page
            }
        ' "$figma_data")
        
        if [ -z "$page_components" ]; then
            echo -e "    ${YELLOW}Warning: No components found on page '$page_name'${NC}"
            continue
        fi
        
        # Save page-specific components
        local page_slug=$(echo "$page_name" | tr ' ' '-' | tr '[:upper:]' '[:lower:]')
        echo "$page_components" | jq -s '.' > "$OUTPUT_DIR/components-${page_slug}.json"
        
        # Track component names and which pages they appear on
        while IFS= read -r component; do
            local comp_name=$(echo "$component" | jq -r '.name')
            local comp_id=$(echo "$component" | jq -r '.id')
            
            # Track which pages this component appears on
            if [ -z "${component_pages[$comp_name]}" ]; then
                component_pages[$comp_name]="$page_name"
                component_map[$comp_name]="$component"
            else
                component_pages[$comp_name]="${component_pages[$comp_name]},$page_name"
            fi
        done < <(echo "$page_components" | jq -c '.')
        
        local count=$(echo "$page_components" | jq -s 'length')
        echo -e "    ${GREEN}✓ Found $count components${NC}"
    done
    
    # Create all components file with page tracking
    echo "[" > "$all_components_file"
    local first=true
    for comp_name in "${!component_map[@]}"; do
        if [ "$first" = true ]; then
            first=false
        else
            echo "," >> "$all_components_file"
        fi
        
        local pages="${component_pages[$comp_name]}"
        local page_count=$(echo "$pages" | tr ',' '\n' | wc -l)
        local is_shared=$([ $page_count -gt 1 ] && echo "true" || echo "false")
        
        echo "${component_map[$comp_name]}" | jq --arg pages "$pages" --arg shared "$is_shared" \
            '. + {pages: ($pages | split(",")), shared: ($shared == "true")}' >> "$all_components_file"
    done
    echo "]" >> "$all_components_file"
    
    # Create shared components file
    jq '[.[] | select(.shared == true)]' "$all_components_file" > "$OUTPUT_DIR/shared-components.json"
    
    # Create page-specific components files
    for page_name in "${PAGE_NAMES[@]}"; do
        local page_slug=$(echo "$page_name" | tr ' ' '-' | tr '[:upper:]' '[:lower:]')
        jq --arg page "$page_name" '[.[] | select(.pages | contains([$page]))]' \
            "$all_components_file" > "$OUTPUT_DIR/page-${page_slug}-components.json"
    done
    
    local total_count=$(jq 'length' "$all_components_file")
    local shared_count=$(jq 'length' "$OUTPUT_DIR/shared-components.json")
    
    echo -e "\n${GREEN}✓ Extraction complete:${NC}"
    echo -e "  Total unique components: $total_count"
    echo -e "  Shared components: $shared_count"
    echo -e "  Page-specific components: $((total_count - shared_count))"
}

# Generate HTML structure based on component type
generate_html_content() {
    local component_name="$1"
    local component_data="$2"
    
    cat << EOF
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>$component_name</title>
    
    <!-- Bootstrap CSS -->
    <link href="https://cdn.jsdelivr.net/npm/bootstrap@$BOOTSTRAP_VERSION/dist/css/bootstrap.min.css" rel="stylesheet">
    
    <!-- Custom CSS -->
    <style>
        /* Add your custom styles here */
        .component-container {
            padding: 2rem;
        }
    </style>
</head>
<body>
    <div class="component-container">
        <!-- Component: $component_name -->
        <div class="container">
            <div class="row">
                <div class="col-12">
                    <!-- TODO: Implement component structure -->
                    <!-- Original Figma component: $component_name -->
                    <div class="card">
                        <div class="card-body">
                            <h5 class="card-title">$component_name</h5>
                            <p class="card-text">Component placeholder - customize based on Figma design</p>
                        </div>
                    </div>
                </div>
            </div>
        </div>
    </div>
    
    <!-- Bootstrap JS Bundle -->
    <script src="https://cdn.jsdelivr.net/npm/bootstrap@$BOOTSTRAP_VERSION/dist/js/bootstrap.bundle.min.js"></script>
</body>
</html>
EOF
}

# Generate TPL file content
generate_tpl_content() {
    local component_name="$1"
    local pages="$2"
    local is_shared="$3"
    
    local shared_note=""
    if [ "$is_shared" = "true" ]; then
        shared_note="
 * SHARED COMPONENT - Used across multiple pages: $pages
 * Location: /shared/${component_name}.tpl"
    else
        shared_note="
 * Page-specific component: $pages"
    fi
    
    case "$TEMPLATE_ENGINE" in
        smarty)
            cat << EOF
{*
 * Template: $component_name
 * Generated from Figma component$shared_note
 *}

<div class="component-$component_name">
    <div class="container">
        <div class="row">
            <div class="col-12">
                {* TODO: Implement component structure *}
                <div class="card">
                    <div class="card-body">
                        <h5 class="card-title">{\$title|default:"$component_name"}</h5>
                        <p class="card-text">{\$content|default:"Component content"}</p>
                    </div>
                </div>
            </div>
        </div>
    </div>
</div>
EOF
            ;;
        twig)
            cat << EOF
{#
 # Template: $component_name
 # Generated from Figma component$shared_note
 #}

<div class="component-{{ component_name|default('$component_name') }}">
    <div class="container">
        <div class="row">
            <div class="col-12">
                {# TODO: Implement component structure #}
                <div class="card">
                    <div class="card-body">
                        <h5 class="card-title">{{ title|default('$component_name') }}</h5>
                        <p class="card-text">{{ content|default('Component content') }}</p>
                    </div>
                </div>
            </div>
        </div>
    </div>
</div>
EOF
            ;;
        *)
            cat << EOF
<!-- Template: $component_name -->
<!-- Generated from Figma component$shared_note -->

<div class="component-$component_name">
    <div class="container">
        <div class="row">
            <div class="col-12">
                <!-- TODO: Implement component structure -->
                <div class="card">
                    <div class="card-body">
                        <h5 class="card-title">$component_name</h5>
                        <p class="card-text">Component content</p>
                    </div>
                </div>
            </div>
        </div>
    </div>
</div>
EOF
            ;;
    esac
}

# Create HTML and TPL files for each component
create_component_files() {
    echo -e "${YELLOW}Creating HTML and TPL files with folder structure...${NC}"
    
    local components_file="$OUTPUT_DIR/all-components.json"
    local shared_components_file="$OUTPUT_DIR/shared-components.json"
    
    # Create directory structure
    local html_dir="$OUTPUT_DIR/html"
    local tpl_dir="$OUTPUT_DIR/tpl"
    
    mkdir -p "$html_dir/shared" "$tpl_dir/shared"
    
    # Create page-specific directories
    for page_name in "${PAGE_NAMES[@]}"; do
        local page_slug=$(echo "$page_name" | tr ' ' '-' | tr '[:upper:]' '[:lower:]')
        mkdir -p "$html_dir/$page_slug" "$tpl_dir/$page_slug" "$OUTPUT_DIR/metadata/$page_slug"
    done
    
    mkdir -p "$OUTPUT_DIR/metadata/shared"
    
    # Determine which components to process
    local components_to_process="$components_file"
    if [ "$SHARED_ONLY" = true ]; then
        components_to_process="$shared_components_file"
        echo -e "  ${YELLOW}Processing shared components only${NC}"
    fi
    
    local component_count=$(jq 'length' "$components_to_process")
    
    if [ "$component_count" -eq 0 ]; then
        echo -e "  ${RED}No components to process${NC}"
        return
    fi
    
    for i in $(seq 0 $(($component_count - 1))); do
        local component=$(jq -r ".[$i]" "$components_to_process")
        local component_name=$(echo "$component" | jq -r '.name' | tr ' ' '-' | tr '[:upper:]' '[:lower:]')
        local component_id=$(echo "$component" | jq -r '.id')
        local is_shared=$(echo "$component" | jq -r '.shared')
        local pages=$(echo "$component" | jq -r '.pages | join(", ")')
        
        # Determine output directory
        local output_subdir=""
        if [ "$is_shared" = "true" ]; then
            output_subdir="shared"
            echo -e "  Creating shared component: ${GREEN}$component_name${NC} (used in: $pages)"
        else
            # Use the first page as the directory
            local first_page=$(echo "$component" | jq -r '.pages[0]')
            output_subdir=$(echo "$first_page" | tr ' ' '-' | tr '[:upper:]' '[:lower:]')
            echo -e "  Creating component: ${GREEN}$component_name${NC} (page: $first_page)"
        fi
        
        # Generate HTML file
        generate_html_content "$component_name" "$component" > "$html_dir/$output_subdir/${component_name}.html"
        
        # Generate TPL file
        generate_tpl_content "$component_name" "$pages" "$is_shared" > "$tpl_dir/$output_subdir/${component_name}.tpl"
        
        # Save component metadata
        echo "$component" | jq '.' > "$OUTPUT_DIR/metadata/$output_subdir/${component_name}.json"
    done
    
    echo -e "${GREEN}✓ Created $component_count HTML and TPL files${NC}"
    
    # Create index files for each directory
    create_index_files
}

# Create index files for easy navigation
create_index_files() {
    echo -e "${YELLOW}Creating index files...${NC}"
    
    local html_dir="$OUTPUT_DIR/html"
    local components_file="$OUTPUT_DIR/all-components.json"
    
    # Create main index.html
    cat << 'EOF' > "$html_dir/index.html"
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Figma Components Library</title>
    <link href="https://cdn.jsdelivr.net/npm/bootstrap@5.3.2/dist/css/bootstrap.min.css" rel="stylesheet">
    <style>
        .component-card { transition: transform 0.2s; }
        .component-card:hover { transform: translateY(-5px); }
        .badge-shared { background-color: #0d6efd; }
        .badge-page { background-color: #6c757d; }
    </style>
</head>
<body>
    <div class="container py-5">
        <h1 class="mb-4">Figma Components Library</h1>
EOF
    
    echo "        <div class=\"alert alert-info\">" >> "$html_dir/index.html"
    echo "            <strong>Pages:</strong> ${PAGE_NAMES[*]}" >> "$html_dir/index.html"
    echo "        </div>" >> "$html_dir/index.html"
    
    # Shared components section
    local shared_count=$(jq 'length' "$OUTPUT_DIR/shared-components.json")
    if [ "$shared_count" -gt 0 ]; then
        cat << EOF >> "$html_dir/index.html"
        
        <h2 class="mt-5 mb-3">Shared Components <span class="badge badge-shared">$shared_count</span></h2>
        <div class="row g-3">
EOF
        
        for i in $(seq 0 $(($shared_count - 1))); do
            local component=$(jq -r ".[$i]" "$OUTPUT_DIR/shared-components.json")
            local comp_name=$(echo "$component" | jq -r '.name')
            local comp_slug=$(echo "$comp_name" | tr ' ' '-' | tr '[:upper:]' '[:lower:]')
            local pages=$(echo "$component" | jq -r '.pages | join(", ")')
            
            cat << EOF >> "$html_dir/index.html"
            <div class="col-md-4">
                <div class="card component-card h-100">
                    <div class="card-body">
                        <h5 class="card-title">$comp_name</h5>
                        <p class="card-text text-muted small">Used in: $pages</p>
                        <a href="shared/${comp_slug}.html" class="btn btn-sm btn-primary">View Component</a>
                    </div>
                </div>
            </div>
EOF
        done
        
        echo "        </div>" >> "$html_dir/index.html"
    fi
    
    # Page-specific sections
    for page_name in "${PAGE_NAMES[@]}"; do
        local page_slug=$(echo "$page_name" | tr ' ' '-' | tr '[:upper:]' '[:lower:]')
        local page_file="$OUTPUT_DIR/page-${page_slug}-components.json"
        local page_only_components=$(jq '[.[] | select(.shared == false)]' "$page_file")
        local page_count=$(echo "$page_only_components" | jq 'length')
        
        if [ "$page_count" -gt 0 ]; then
            cat << EOF >> "$html_dir/index.html"
        
        <h2 class="mt-5 mb-3">$page_name Components <span class="badge badge-page">$page_count</span></h2>
        <div class="row g-3">
EOF
            
            for i in $(seq 0 $(($page_count - 1))); do
                local component=$(echo "$page_only_components" | jq -r ".[$i]")
                local comp_name=$(echo "$component" | jq -r '.name')
                local comp_slug=$(echo "$comp_name" | tr ' ' '-' | tr '[:upper:]' '[:lower:]')
                
                cat << EOF >> "$html_dir/index.html"
            <div class="col-md-4">
                <div class="card component-card h-100">
                    <div class="card-body">
                        <h5 class="card-title">$comp_name</h5>
                        <p class="card-text text-muted small">Page-specific</p>
                        <a href="${page_slug}/${comp_slug}.html" class="btn btn-sm btn-primary">View Component</a>
                    </div>
                </div>
            </div>
EOF
            done
            
            echo "        </div>" >> "$html_dir/index.html"
        fi
    done
    
    cat << 'EOF' >> "$html_dir/index.html"
    </div>
    <script src="https://cdn.jsdelivr.net/npm/bootstrap@5.3.2/dist/js/bootstrap.bundle.min.js"></script>
</body>
</html>
EOF
    
    echo -e "${GREEN}✓ Created index.html${NC}"
}

# Create README file
create_readme() {
    cat << EOF > "$OUTPUT_DIR/README.md"
# Figma Components Export

This directory contains HTML and TPL files generated from Figma components across multiple pages.

## Structure

\`\`\`
.
├── html/
│   ├── index.html                    # Main component library index
│   ├── shared/                       # Components used across multiple pages
│   │   ├── component-1.html
│   │   └── component-2.html
$(for page in "${PAGE_NAMES[@]}"; do
    page_slug=$(echo "$page" | tr ' ' '-' | tr '[:upper:]' '[:lower:]')
    echo "│   ├── ${page_slug}/                   # $page page-specific components"
done)
│   └── ...
├── tpl/
│   ├── shared/                       # Shared template files
$(for page in "${PAGE_NAMES[@]}"; do
    page_slug=$(echo "$page" | tr ' ' '-' | tr '[:upper:]' '[:lower:]')
    echo "│   ├── ${page_slug}/                   # $page templates"
done)
│   └── ...
├── metadata/
│   ├── shared/                       # Component metadata
$(for page in "${PAGE_NAMES[@]}"; do
    page_slug=$(echo "$page" | tr ' ' '-' | tr '[:upper:]' '[:lower:]')
    echo "│   ├── ${page_slug}/                   # $page metadata"
done)
│   └── ...
├── all-components.json               # All components with page tracking
├── shared-components.json            # Components used on multiple pages
$(for page in "${PAGE_NAMES[@]}"; do
    page_slug=$(echo "$page" | tr ' ' '-' | tr '[:upper:]' '[:lower:]')
    echo "├── page-${page_slug}-components.json  # $page components"
done)
├── figma-data.json                   # Complete Figma file data
└── README.md
\`\`\`

## Component Organization

### Shared Components
Components that appear on **multiple pages** are automatically placed in the \`shared/\` directory.
These represent your reusable design system components.

**Shared components found:** $(jq 'length' "$OUTPUT_DIR/shared-components.json")

### Page-Specific Components
Components unique to a single page are organized in page-specific directories.

EOF

    # Add page statistics
    for page_name in "${PAGE_NAMES[@]}"; do
        local page_slug=$(echo "$page_name" | tr ' ' '-' | tr '[:upper:]' '[:lower:]')
        local page_file="$OUTPUT_DIR/page-${page_slug}-components.json"
        local total=$(jq 'length' "$page_file")
        local page_only=$(jq '[.[] | select(.shared == false)] | length' "$page_file")
        
        cat << EOF >> "$OUTPUT_DIR/README.md"
**$page_name:**
- Total components: $total
- Page-specific: $page_only
- Shared: $((total - page_only))

EOF
    done

    cat << EOF >> "$OUTPUT_DIR/README.md"

## Bootstrap Version

Bootstrap $BOOTSTRAP_VERSION

## Viewing Components

### Option 1: Index Page
Open \`html/index.html\` in your browser to see all components organized by category.

### Option 2: Individual Files
Navigate to specific component HTML files:
- Shared: \`html/shared/component-name.html\`
- Page-specific: \`html/page-name/component-name.html\`

## Using Templates

### Include Shared Components
\`\`\`$TEMPLATE_ENGINE
{include file="shared/component-name.tpl"}
\`\`\`

### Include Page-Specific Components
\`\`\`$TEMPLATE_ENGINE
{include file="page-name/component-name.tpl"}
\`\`\`

## Understanding Component Classification

A component is considered **shared** when it appears with the same name on multiple pages.
This helps you:
- Identify reusable design system components
- Maintain consistency across pages
- Avoid duplicating code

## Data Files

- \`all-components.json\`: Master list with page tracking
- \`shared-components.json\`: Filtered list of shared components only
- \`page-*-components.json\`: Components associated with each page
- \`figma-data.json\`: Raw Figma API response

## Next Steps

1. Open \`html/index.html\` to browse all components
2. Review shared components - these are candidates for your component library
3. Customize Bootstrap structure to match Figma designs
4. Implement responsive breakpoints
5. Add design tokens for colors, spacing, and typography
6. Integrate templates into your application

## Pages Processed

$(for page in "${PAGE_NAMES[@]}"; do echo "- $page"; done)

## Export Configuration

- **Figma File ID:** $FILE_ID
- **Bootstrap Version:** $BOOTSTRAP_VERSION
- **Template Engine:** $TEMPLATE_ENGINE
- **Generated:** $(date)

---

Generated by Figma to Bootstrap Components Converter
EOF
}

# Main execution
main() {
    echo -e "${GREEN}=== Figma to Bootstrap Components Converter ===${NC}\n"
    
    check_dependencies
    parse_args "$@"
    
    echo -e "Configuration:"
    echo -e "  Pages: ${YELLOW}${PAGE_NAMES[*]}${NC}"
    echo -e "  Output: ${YELLOW}$OUTPUT_DIR${NC}"
    echo -e "  Shared only: ${YELLOW}$SHARED_ONLY${NC}\n"
    
    # Create output directory structure
    mkdir -p "$OUTPUT_DIR/html" "$OUTPUT_DIR/tpl" "$OUTPUT_DIR/metadata"
    
    # Execute conversion steps
    fetch_figma_data
    extract_components
    create_component_files
    create_readme
    
    echo -e "\n${GREEN}=== Conversion Complete! ===${NC}"
    echo -e "Output directory: ${YELLOW}$OUTPUT_DIR${NC}"
    echo -e "\nFiles created:"
    echo -e "  - Component library index: $OUTPUT_DIR/html/index.html"
    echo -e "  - Shared components: $OUTPUT_DIR/html/shared/"
    for page in "${PAGE_NAMES[@]}"; do
        page_slug=$(echo "$page" | tr ' ' '-' | tr '[:upper:]' '[:lower:]')
        echo -e "  - $page components: $OUTPUT_DIR/html/$page_slug/"
    done
    echo -e "  - Templates: $OUTPUT_DIR/tpl/"
    echo -e "  - Metadata: $OUTPUT_DIR/metadata/"
    echo -e "  - README: $OUTPUT_DIR/README.md"
    echo -e "\nNext steps:"
    echo -e "  1. Open ${YELLOW}$OUTPUT_DIR/html/index.html${NC} in a browser"
    echo -e "  2. Review the README.md file"
    echo -e "  3. Customize shared components first (they're used across multiple pages)"
    echo -e "  4. Implement page-specific components"
}

# Run main function
main "$@"

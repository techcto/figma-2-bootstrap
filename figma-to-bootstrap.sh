#!/opt/homebrew/bin/bash

# Figma to Bootstrap Components Converter
# This script extracts components and frames from a Figma page and creates individual HTML and TPL files

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

Convert Figma components and frames to HTML/TPL files with Bootstrap

Required:
    -k, --api-key KEY       Figma API key (or set FIGMA_API_KEY env var)
    -f, --file-id ID        Figma file ID
    -p, --page-names NAMES  Comma-separated page names (e.g., "Components,Forms,Layouts")
                           Or use multiple -p flags: -p "Components" -p "Forms"

Optional:
    -r, --frame-names NAMES Comma-separated frame names to extract (e.g., "Header,Footer")
                           Or use multiple -r flags: -r "Header" -r "Footer"
                           Extracts both the frame itself and components within it
    -o, --output-dir DIR    Output directory (default: ./figma-components)
    -b, --bootstrap VER     Bootstrap version (default: 5.3.2)
    -t, --template-engine   Template engine for .tpl files (default: smarty)
    -s, --shared-only      Only extract components that appear on multiple pages
    --output-frame-html     Output a single HTML file with a complete frame and all components
    --frame-name FRAME      Specific frame name to output as complete HTML (requires --output-frame-html)
    -h, --help             Show this help message

Examples:
    # Single page with components
    $0 -k YOUR_API_KEY -f FILE_ID -p "Components" -o ./output
    
    # Multiple pages with specific frames
    $0 -k YOUR_API_KEY -f FILE_ID -p "Components,Forms" -r "Header,Footer"
    
    # Extract frames and all components from a page
    $0 -k YOUR_API_KEY -f FILE_ID -p "Homepage" -r "Hero Section"
    
    # Extract only shared components
    $0 -k YOUR_API_KEY -f FILE_ID -p "Page1,Page2" -s
    
    # Output complete HTML for a specific frame with all components
    $0 -k YOUR_API_KEY -f FILE_ID -p "Homepage" -r "Hero Section" --output-frame-html --frame-name "Hero Section"

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
    FRAME_NAMES=()
    OUTPUT_DIR="./figma-components"
    BOOTSTRAP_VERSION="5.3.2"
    TEMPLATE_ENGINE="smarty"
    SHARED_ONLY=false
    OUTPUT_FRAME_HTML=false
    FRAME_FOR_HTML=""
    
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
            -r|--frame-names)
                # Support both comma-separated and multiple flags
                IFS=',' read -ra FRAMES <<< "$2"
                for frame in "${FRAMES[@]}"; do
                    # Trim whitespace
                    frame=$(echo "$frame" | xargs)
                    if [ ! -z "$frame" ]; then
                        FRAME_NAMES+=("$frame")
                    fi
                done
                shift 2
                ;;
            --frame-name)
                FRAME_FOR_HTML="$2"
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
            --output-frame-html)
                OUTPUT_FRAME_HTML=true
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

# Extract frames from the specified pages
extract_frames() {
    if [ ${#FRAME_NAMES[@]} -eq 0 ]; then
        return
    fi
    
    echo -e "${YELLOW}Extracting frames from ${#PAGE_NAMES[@]} page(s)...${NC}"
    
    local figma_data="$OUTPUT_DIR/figma-data.json"
    local all_frames_file="$OUTPUT_DIR/all-frames.json"
    
    # Initialize arrays to track frames
    declare -A frame_map
    declare -A frame_pages
    
    # Extract frames from each page
    for page_name in "${PAGE_NAMES[@]}"; do
        echo -e "  Processing page: ${GREEN}$page_name${NC}"
        
        # Build jq filter for frame names
        local frame_filter=""
        for frame_name in "${FRAME_NAMES[@]}"; do
            if [ -z "$frame_filter" ]; then
                frame_filter=".name == \"$frame_name\""
            else
                frame_filter="$frame_filter or .name == \"$frame_name\""
            fi
        done
        
        local page_frames=$(jq -r --arg page "$page_name" "
            .document.children[] | 
            select(.name == \$page) | 
            .children[] |
            select(.type? == \"FRAME\" and ($frame_filter)) | 
            {
                id: .id,
                name: .name,
                type: .type,
                bounds: .absoluteBoundingBox,
                children: .children,
                page: \$page
            }
        " "$figma_data")
        
        if [ -z "$page_frames" ]; then
            echo -e "    ${YELLOW}Warning: No matching frames found on page '$page_name'${NC}"
            continue
        fi
        
        # Save page-specific frames
        local page_slug=$(echo "$page_name" | tr ' ' '-' | tr '[:upper:]' '[:lower:]')
        echo "$page_frames" | jq -s '.' > "$OUTPUT_DIR/frames-${page_slug}.json"
        
        # Track frame names and which pages they appear on
        while IFS= read -r frame; do
            local frame_name=$(echo "$frame" | jq -r '.name')
            local frame_id=$(echo "$frame" | jq -r '.id')
            
            # Track which pages this frame appears on
            if [ -z "${frame_pages[$frame_name]}" ]; then
                frame_pages[$frame_name]="$page_name"
                frame_map[$frame_name]="$frame"
            else
                frame_pages[$frame_name]="${frame_pages[$frame_name]},$page_name"
            fi
        done < <(echo "$page_frames" | jq -c '.')
        
        local count=$(echo "$page_frames" | jq -s 'length')
        echo -e "    ${GREEN}✓ Found $count frame(s)${NC}"
    done
    
    # Create all frames file with page tracking
    echo "[" > "$all_frames_file"
    local first=true
    for frame_name in "${!frame_map[@]}"; do
        if [ "$first" = true ]; then
            first=false
        else
            echo "," >> "$all_frames_file"
        fi
        
        local pages="${frame_pages[$frame_name]}"
        local page_count=$(echo "$pages" | tr ',' '\n' | wc -l)
        local is_shared=$([ $page_count -gt 1 ] && echo "true" || echo "false")
        
        echo "${frame_map[$frame_name]}" | jq --arg pages "$pages" --arg shared "$is_shared" \
            '. + {pages: ($pages | split(",")), shared: ($shared == "true")}' >> "$all_frames_file"
    done
    echo "]" >> "$all_frames_file"
    
    # Create shared frames file
    jq '[.[] | select(.shared == true)]' "$all_frames_file" > "$OUTPUT_DIR/shared-frames.json"
    
    local total_count=$(jq 'length' "$all_frames_file")
    local shared_count=$(jq 'length' "$OUTPUT_DIR/shared-frames.json")
    
    echo -e "\n${GREEN}✓ Frame extraction complete:${NC}"
    echo -e "  Total unique frames: $total_count"
    echo -e "  Shared frames: $shared_count"
    echo -e "  Page-specific frames: $((total_count - shared_count))"
}

# Extract components within frames
extract_frame_components() {
    if [ ${#FRAME_NAMES[@]} -eq 0 ]; then
        return
    fi
    
    echo -e "${YELLOW}Extracting components within frames...${NC}"
    
    local all_frames_file="$OUTPUT_DIR/all-frames.json"
    local frame_components_file="$OUTPUT_DIR/frame-components.json"
    
    if [ ! -f "$all_frames_file" ]; then
        echo -e "  ${YELLOW}No frames file found, skipping frame component extraction${NC}"
        return
    fi
    
    # Extract all components within frames
    local frame_count=$(jq 'length' "$all_frames_file")
    
    echo "[" > "$frame_components_file"
    local first=true
    
    for i in $(seq 0 $(($frame_count - 1))); do
        local frame=$(jq -r ".[$i]" "$all_frames_file")
        local frame_name=$(echo "$frame" | jq -r '.name')
        local frame_pages=$(echo "$frame" | jq -r '.pages | join(", ")')
        
        echo -e "  Scanning frame: ${GREEN}$frame_name${NC}"
        
        # Extract components within this frame
        local components=$(echo "$frame" | jq -c '
            .. | 
            select(.type? == "COMPONENT" or .type? == "INSTANCE") | 
            {
                id: .id,
                name: .name,
                type: .type,
                bounds: .absoluteBoundingBox,
                children: .children
            }
        ')
        
        if [ ! -z "$components" ]; then
            while IFS= read -r component; do
                if [ "$first" = true ]; then
                    first=false
                else
                    echo "," >> "$frame_components_file"
                fi
                
                echo "$component" | jq --arg frame "$frame_name" --arg pages "$frame_pages" \
                    '. + {frame: $frame, frame_pages: ($pages | split(", "))}' >> "$frame_components_file"
            done < <(echo "$components")
            
            local comp_count=$(echo "$components" | wc -l)
            echo -e "    ${GREEN}✓ Found $comp_count component(s)${NC}"
        else
            echo -e "    ${YELLOW}No components found in frame${NC}"
        fi
    done
    
    echo "]" >> "$frame_components_file"
    
    local total_frame_comps=$(jq 'length' "$frame_components_file")
    echo -e "${GREEN}✓ Found $total_frame_comps total components within frames${NC}"
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

# Generate HTML structure for frames
generate_frame_html_content() {
    local frame_name="$1"
    local frame_data="$2"
    
    cat << EOF
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>$frame_name - Frame</title>
    
    <!-- Bootstrap CSS -->
    <link href="https://cdn.jsdelivr.net/npm/bootstrap@$BOOTSTRAP_VERSION/dist/css/bootstrap.min.css" rel="stylesheet">
    
    <!-- Custom CSS -->
    <style>
        /* Add your custom styles here */
        .frame-container {
            padding: 2rem;
        }
    </style>
</head>
<body>
    <div class="frame-container">
        <!-- Frame: $frame_name -->
        <div class="container-fluid">
            <div class="row">
                <div class="col-12">
                    <!-- TODO: Implement frame structure -->
                    <!-- Original Figma frame: $frame_name -->
                    <section class="frame-section">
                        <h2>$frame_name</h2>
                        <p>Frame content placeholder - customize based on Figma design</p>
                        <!-- Components within this frame should be placed here -->
                    </section>
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

# Generate TPL file content for frames
generate_frame_tpl_content() {
    local frame_name="$1"
    local pages="$2"
    local is_shared="$3"
    
    local shared_note=""
    if [ "$is_shared" = "true" ]; then
        shared_note="
 * SHARED FRAME - Used across multiple pages: $pages
 * Location: /shared/frames/${frame_name}.tpl"
    else
        shared_note="
 * Page-specific frame: $pages"
    fi
    
    case "$TEMPLATE_ENGINE" in
        smarty)
            cat << EOF
{*
 * Frame Template: $frame_name
 * Generated from Figma frame$shared_note
 *}

<section class="frame-$frame_name">
    <div class="container-fluid">
        <div class="row">
            <div class="col-12">
                {* TODO: Implement frame structure *}
                <div class="frame-content">
                    <h2>{\$frame_title|default:"$frame_name"}</h2>
                    <div class="frame-body">
                        {\$frame_content|default:"Frame content"}
                    </div>
                </div>
            </div>
        </div>
    </div>
</section>
EOF
            ;;
        twig)
            cat << EOF
{#
 # Frame Template: $frame_name
 # Generated from Figma frame$shared_note
 #}

<section class="frame-{{ frame_name|default('$frame_name') }}">
    <div class="container-fluid">
        <div class="row">
            <div class="col-12">
                {# TODO: Implement frame structure #}
                <div class="frame-content">
                    <h2>{{ frame_title|default('$frame_name') }}</h2>
                    <div class="frame-body">
                        {{ frame_content|default('Frame content') }}
                    </div>
                </div>
            </div>
        </div>
    </div>
</section>
EOF
            ;;
        *)
            cat << EOF
<!-- Frame Template: $frame_name -->
<!-- Generated from Figma frame$shared_note -->

<section class="frame-$frame_name">
    <div class="container-fluid">
        <div class="row">
            <div class="col-12">
                <!-- TODO: Implement frame structure -->
                <div class="frame-content">
                    <h2>$frame_name</h2>
                    <div class="frame-body">
                        Frame content
                    </div>
                </div>
            </div>
        </div>
    </div>
</section>
EOF
            ;;
    esac
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

# Create HTML and TPL files for frames
create_frame_files() {
    if [ ${#FRAME_NAMES[@]} -eq 0 ]; then
        return
    fi
    
    echo -e "${YELLOW}Creating HTML and TPL files for frames...${NC}"
    
    local all_frames_file="$OUTPUT_DIR/all-frames.json"
    
    if [ ! -f "$all_frames_file" ]; then
        echo -e "  ${YELLOW}No frames to process${NC}"
        return
    fi
    
    local frame_count=$(jq 'length' "$all_frames_file")
    
    if [ "$frame_count" -eq 0 ]; then
        echo -e "  ${RED}No frames to process${NC}"
        return
    fi
    
    # Create frames subdirectories
    local html_dir="$OUTPUT_DIR/components"
    local tpl_dir="$OUTPUT_DIR/tpl"
    
    mkdir -p "$html_dir/shared/frames" "$tpl_dir/shared/frames"
    
    for page_name in "${PAGE_NAMES[@]}"; do
        local page_slug=$(echo "$page_name" | tr ' ' '-' | tr '[:upper:]' '[:lower:]')
        mkdir -p "$html_dir/$page_slug/frames" "$tpl_dir/$page_slug/frames" "$OUTPUT_DIR/metadata/$page_slug/frames"
    done
    
    mkdir -p "$OUTPUT_DIR/metadata/shared/frames"
    
    for i in $(seq 0 $(($frame_count - 1))); do
        local frame=$(jq -r ".[$i]" "$all_frames_file")
        local frame_name=$(echo "$frame" | jq -r '.name' | tr ' ' '-' | tr '[:upper:]' '[:lower:]')
        local frame_id=$(echo "$frame" | jq -r '.id')
        local is_shared=$(echo "$frame" | jq -r '.shared')
        local pages=$(echo "$frame" | jq -r '.pages | join(", ")')
        
        # Determine output directory
        local output_subdir=""
        if [ "$is_shared" = "true" ]; then
            output_subdir="shared/frames"
            echo -e "  Creating shared frame: ${GREEN}$frame_name${NC} (used in: $pages)"
        else
            # Use the first page as the directory
            local first_page=$(echo "$frame" | jq -r '.pages[0]')
            output_subdir="$(echo "$first_page" | tr ' ' '-' | tr '[:upper:]' '[:lower:]')/frames"
            echo -e "  Creating frame: ${GREEN}$frame_name${NC} (page: $first_page)"
        fi
        
        # Generate HTML file
        generate_frame_html_content "$frame_name" "$frame" > "$html_dir/$output_subdir/${frame_name}.html"
        
        # Generate TPL file
        generate_frame_tpl_content "$frame_name" "$pages" "$is_shared" > "$tpl_dir/$output_subdir/${frame_name}.tpl"
        
        # Save frame metadata
        echo "$frame" | jq '.' > "$OUTPUT_DIR/metadata/$output_subdir/${frame_name}.json"
    done
    
    echo -e "${GREEN}✓ Created $frame_count frame HTML and TPL files${NC}"
}

# Create HTML and TPL files for components within frames
create_frame_component_files() {
    if [ ${#FRAME_NAMES[@]} -eq 0 ]; then
        return
    fi
    
    local frame_components_file="$OUTPUT_DIR/frame-components.json"
    
    if [ ! -f "$frame_components_file" ]; then
        return
    fi
    
    local comp_count=$(jq 'length' "$frame_components_file")
    
    if [ "$comp_count" -eq 0 ]; then
        return
    fi
    
    echo -e "${YELLOW}Creating HTML and TPL files for components within frames...${NC}"
    
    local html_dir="$OUTPUT_DIR/components"
    local tpl_dir="$OUTPUT_DIR/tpl"
    
    # Create frame-components subdirectories
    mkdir -p "$html_dir/frame-components" "$tpl_dir/frame-components" "$OUTPUT_DIR/metadata/frame-components"
    
    for i in $(seq 0 $(($comp_count - 1))); do
        local component=$(jq -r ".[$i]" "$frame_components_file")
        local component_name=$(echo "$component" | jq -r '.name' | tr ' ' '-' | tr '[:upper:]' '[:lower:]')
        local frame_name=$(echo "$component" | jq -r '.frame')
        local frame_slug=$(echo "$frame_name" | tr ' ' '-' | tr '[:upper:]' '[:lower:]')
        local pages=$(echo "$component" | jq -r '.frame_pages | join(", ")')
        
        echo -e "  Creating frame component: ${GREEN}$component_name${NC} (in frame: $frame_name)"
        
        # Generate HTML file
        generate_html_content "$component_name" "$component" > "$html_dir/frame-components/${frame_slug}-${component_name}.html"
        
        # Generate TPL file
        generate_tpl_content "$component_name" "$pages" "false" > "$tpl_dir/frame-components/${frame_slug}-${component_name}.tpl"
        
        # Save component metadata
        echo "$component" | jq '.' > "$OUTPUT_DIR/metadata/frame-components/${frame_slug}-${component_name}.json"
    done
    
    echo -e "${GREEN}✓ Created $comp_count frame component files${NC}"
}

# Create HTML and TPL files for each component
create_component_files() {
    echo -e "${YELLOW}Creating HTML and TPL files with folder structure...${NC}"
    
    local components_file="$OUTPUT_DIR/all-components.json"
    local shared_components_file="$OUTPUT_DIR/shared-components.json"
    
    # Create directory structure
    local html_dir="$OUTPUT_DIR/components"
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
    
    # Create frame files
    create_frame_files
    create_frame_component_files
    
    # Create index files for each directory
    create_index_files
}

# Recursively extract all child elements (components and groups) from a frame
extract_frame_children() {
    local element="$1"
    
    # Extract current element if it's a component or instance
    if echo "$element" | jq -e '.type == "COMPONENT" or .type == "INSTANCE"' > /dev/null 2>&1; then
        echo "$element" | jq '{
            id: .id,
            name: .name,
            type: .type,
            bounds: .absoluteBoundingBox,
            children: .children
        }'
    fi
    
    # Recursively process children
    if echo "$element" | jq -e '.children' > /dev/null 2>&1; then
        echo "$element" | jq -c '.children[]' | while IFS= read -r child; do
            extract_frame_children "$child"
        done
    fi
}

# Generate complete HTML for a frame including all child components
generate_frame_complete_html() {
    local frame_name="$1"
    local frame_data="$2"
    local page_name="$3"
    local frame_components_list="$4"
    
    cat << EOF
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>$frame_name - Complete Frame</title>
    
    <!-- Bootstrap CSS -->
    <link href="https://cdn.jsdelivr.net/npm/bootstrap@$BOOTSTRAP_VERSION/dist/css/bootstrap.min.css" rel="stylesheet">
    
    <!-- Custom CSS -->
    <style>
        body {
            background-color: #f8f9fa;
            padding: 2rem;
        }
        
        .frame-wrapper {
            background: white;
            border-radius: 8px;
            box-shadow: 0 2px 8px rgba(0, 0, 0, 0.1);
            padding: 2rem;
            margin-bottom: 2rem;
        }
        
        .frame-header {
            border-bottom: 2px solid #dee2e6;
            padding-bottom: 1rem;
            margin-bottom: 2rem;
        }
        
        .frame-header h1 {
            margin: 0;
            color: #212529;
        }
        
        .frame-header .badge {
            margin-left: 1rem;
            font-size: 0.85rem;
        }
        
        .frame-meta {
            font-size: 0.875rem;
            color: #6c757d;
            margin-top: 0.5rem;
        }
        
        .frame-content {
            margin: 2rem 0;
        }
        
        .component-section {
            margin-bottom: 2rem;
            padding: 1.5rem;
            background: #f8f9fa;
            border-left: 4px solid #007bff;
            border-radius: 4px;
        }
        
        .component-section h3 {
            margin-top: 0;
            color: #007bff;
            font-size: 1rem;
        }
        
        .component-section .component-content {
            margin-top: 1rem;
            padding: 1rem;
            background: white;
            border-radius: 4px;
        }
        
        .frame-bounds-info {
            font-size: 0.75rem;
            color: #999;
            margin-top: 0.5rem;
        }
    </style>
</head>
<body>
    <div class="container-fluid">
        <div class="frame-wrapper">
            <div class="frame-header">
                <h1>$frame_name</h1>
                <div class="frame-meta">
                    <strong>Source:</strong> Figma Page: <em>$page_name</em>
                </div>
            </div>
            
            <div class="frame-content">
EOF

    # Add component sections
    if [ ! -z "$frame_components_list" ]; then
        echo "$frame_components_list" | jq -c '.[]' | while IFS= read -r component; do
            local comp_name=$(echo "$component" | jq -r '.name')
            local comp_id=$(echo "$component" | jq -r '.id')
            local comp_bounds=$(echo "$component" | jq -r '.bounds | "\(.x),\(.y),\(.width)x\(.height)"')
            
            cat << COMPONENT
                <div class="component-section">
                    <h3>📦 $comp_name</h3>
                    <div class="component-content">
                        <!-- Component: $comp_name -->
                        <div class="card">
                            <div class="card-body">
                                <h5 class="card-title">$comp_name</h5>
                                <p class="card-text">Component placeholder - customize based on Figma design</p>
                                <small class="text-muted d-block mt-2">
                                    <strong>Position:</strong> $comp_bounds<br>
                                    <strong>ID:</strong> $comp_id
                                </small>
                            </div>
                        </div>
                    </div>
                </div>
COMPONENT
        done
    fi

    cat << EOF
            </div>
            
            <div class="frame-bounds-info">
                <strong>Frame Bounds:</strong> $(echo "$frame_data" | jq -r '.bounds | "\(.x), \(.y) - \(.width)x\(.height)"')
            </div>
        </div>
    </div>
    
    <!-- Bootstrap JS Bundle -->
    <script src="https://cdn.jsdelivr.net/npm/bootstrap@$BOOTSTRAP_VERSION/dist/js/bootstrap.bundle.min.js"></script>
</body>
</html>
EOF
}

# Output complete HTML for a specific frame with all components
output_frame_html() {
    local target_frame="$1"
    local output_file="$2"
    
    echo -e "${YELLOW}Generating complete HTML for frame: ${GREEN}$target_frame${NC}"
    
    # Create frames directory
    mkdir -p "$OUTPUT_DIR/frames"
    
    local all_frames_file="$OUTPUT_DIR/all-frames.json"
    local frame_components_file="$OUTPUT_DIR/frame-components.json"
    
    if [ ! -f "$all_frames_file" ]; then
        echo -e "${RED}Error: No frames file found. Did you extract frames with -r flag?${NC}"
        exit 1
    fi
    
    # Find the frame by name
    local frame_data=$(jq --arg fname "$target_frame" '.[] | select(.name == $fname)' "$all_frames_file")
    
    if [ -z "$frame_data" ]; then
        echo -e "${RED}Error: Frame '$target_frame' not found${NC}"
        exit 1
    fi
    
    # Get page name from frame
    local page_name=$(echo "$frame_data" | jq -r '.pages[0]')
    
    # Extract components from this frame
    local frame_components="[]"
    if [ -f "$frame_components_file" ]; then
        frame_components=$(jq --arg fname "$target_frame" '[.[] | select(.frame == $fname)]' "$frame_components_file")
    fi
    
    # Generate the complete HTML
    generate_frame_complete_html "$target_frame" "$frame_data" "$page_name" "$frame_components" > "$output_file"
    
    echo -e "${GREEN}✓ Frame HTML output saved to: ${YELLOW}$output_file${NC}"
}

# ============================================
# Main Execution
# ============================================

# Check dependencies
check_dependencies

# Parse command line arguments
parse_args "$@"

# Create output directory
mkdir -p "$OUTPUT_DIR"

# Fetch Figma file data
fetch_figma_data

# If output-frame-html mode, extract frames and output HTML
if [ "$OUTPUT_FRAME_HTML" = true ]; then
    if [ -z "$FRAME_FOR_HTML" ]; then
        echo -e "${RED}Error: --frame-name is required with --output-frame-html${NC}"
        usage
    fi
    
    # Extract frames if specified
    extract_frames
    
    # Extract components within frames
    extract_frame_components
    
    # Output the frame HTML
    output_html="$OUTPUT_DIR/frames/${FRAME_FOR_HTML// /-}.html"
    output_frame_html "$FRAME_FOR_HTML" "$output_html"
else
    # Standard extraction mode
    # Extract components from pages
    extract_components

    # Extract frames if specified
    extract_frames

    # Extract components within frames
    extract_frame_components

    # Create component files
    create_component_files

    echo -e "${GREEN}✓ Export complete!${NC}"
    echo -e "Output directory: ${YELLOW}$OUTPUT_DIR${NC}"
fi
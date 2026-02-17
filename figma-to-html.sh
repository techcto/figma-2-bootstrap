#!/bin/bash

################################################################################
# Figma to HTML/CSS Converter with Bootstrap
# Converts Figma frames and components to pixel-perfect HTML and CSS
################################################################################

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_FILE="${SCRIPT_DIR}/.env"
OUTPUT_DIR="output"

################################################################################
# Helper Functions
################################################################################

log_error() {
    echo -e "${RED}❌ Error: $1${NC}" >&2
}

log_success() {
    echo -e "${GREEN}✓ $1${NC}" >&2
}

log_info() {
    echo -e "${BLUE}ℹ $1${NC}" >&2
}

log_warning() {
    echo -e "${YELLOW}⚠ $1${NC}" >&2
}

show_usage() {
    cat << EOF
Usage: ./figma-to-html.sh -f <FILE_ID> -p <PAGE_NAME> -c <COMPONENT_NAME> [-o <OUTPUT_DIR>] [-l <LIBRARY_FILE_ID>]

Options:
    -f, --file-id       Figma file ID (required)
    -p, --page          Page name in Figma file (required)
    -c, --component     Frame or component name (required)
    -o, --output        Output directory (default: output)
    -l, --library-file  Figma library file ID to supplement variables (optional)
    -h, --help          Show this help message

Examples:
    ./figma-to-html.sh -f abc123def456 -p "Design" -c "Button"
    ./figma-to-html.sh -f abc123def456 -p "Design" -c "Card" -l libfile123

Variable Resolution (in order of precedence):
    1. Manual variables from variables.json file (if present)
    2. Library file variables (if -l flag provided)
    3. Main file variables (from Figma Variables API if available)
    
    To define manual variables, edit variables.json:
    {
      "variables": {
        "variable-name": "#RRGGBB",
        "color-background": "#EDF1F8"
      }
    }

Requirements:
    - .env file with FIGMA_API_KEY set
    - jq (for JSON parsing)
    - Node.js 16+ (for conversion utilities)

EOF
}

################################################################################
# Config Management
################################################################################

check_config() {
    if [[ ! -f "$CONFIG_FILE" ]]; then
        log_error "Configuration file not found: $CONFIG_FILE"
        log_info "Please create a .env file with your Figma API key:"
        log_info "  cp .env.example .env"
        log_info "  # Edit .env and add your FIGMA_API_KEY"
        exit 1
    fi

    # Source the config file
    # shellcheck disable=SC1090
    source "$CONFIG_FILE"

    if [[ -z "${FIGMA_API_KEY:-}" ]]; then
        log_error "FIGMA_API_KEY not set in $CONFIG_FILE"
        exit 1
    fi
}

check_dependencies() {
    local deps=("jq" "curl" "node")
    local missing=()

    for dep in "${deps[@]}"; do
        if ! command -v "$dep" &> /dev/null; then
            missing+=("$dep")
        fi
    done

    if [[ ${#missing[@]} -gt 0 ]]; then
        log_error "Missing required dependencies: ${missing[*]}"
        log_info "Install them using: brew install ${missing[*]}"
        exit 1
    fi
}

################################################################################
# Figma API Functions
################################################################################

get_figma_file() {
    local file_id="$1"
    local temp_file=$(mktemp)

    log_info "Fetching Figma file: $file_id"

    # Make API request with HTTP code output
    local http_code
    http_code=$(curl -s -w "%{http_code}" -o "$temp_file" \
        -H "X-Figma-Token: ${FIGMA_API_KEY}" \
        "https://api.figma.com/v1/files/${file_id}")

    # Check HTTP status
    if [[ "$http_code" != "200" ]]; then
        local error_msg=$(jq -r '.err // .message // "Unknown error"' "$temp_file" 2>/dev/null || echo "HTTP $http_code")
        log_error "Figma API error ($http_code): $error_msg"
        rm -f "$temp_file"
        exit 1
    fi

    # Double-check for API error responses
    if jq -e '.status' "$temp_file" > /dev/null 2>&1; then
        local error_msg=$(jq -r '.status // .error // "Unknown error"' "$temp_file")
        log_error "Figma API error: $error_msg"
        rm -f "$temp_file"
        exit 1
    fi

    echo "$temp_file"
}

find_page_by_name() {
    local file_data="$1"
    local page_name="$2"

    jq -r ".document.children[] | select(.name == \"$page_name\") | .id" "$file_data"
}

find_frame_by_name() {
    local file_data="$1"
    local page_id="$2"
    local frame_name="$3"

    # Recursively search through all children for the frame
    jq -r "
    def find_frame:
        if .name == \"$frame_name\" then .id
        elif .children then .children[] | find_frame
        else empty
        end;
    
    .document.children[] | select(.id == \"$page_id\") | .children[]? | find_frame
    " "$file_data"
}

get_frame_children() {
    local file_data="$1"
    local frame_id="$2"

    # Get all immediate children of a frame
    jq -r ".document.children[] | .. | objects | select(.id == \"$frame_id\") | .children[]? | {id: .id, name: .name}" "$file_data"
}

get_frame_data() {
    local file_id="$1"
    local node_ids="$2"
    local temp_file=$(mktemp)

    log_info "Fetching frame data for node IDs: $node_ids"

    if ! curl -s \
        -H "X-Figma-Token: ${FIGMA_API_KEY}" \
        "https://api.figma.com/v1/files/${file_id}/nodes?ids=${node_ids}" \
        -o "$temp_file"; then
        log_error "Failed to fetch frame data"
        rm -f "$temp_file"
        exit 1
    fi

    if jq -e '.status' "$temp_file" > /dev/null 2>&1; then
        local error_msg=$(jq -r '.status // .error // "Unknown error"' "$temp_file")
        log_error "Figma API error: $error_msg"
        rm -f "$temp_file"
        exit 1
    fi

    echo "$temp_file"
}

extract_variables_from_file() {
    local file_id="$1"
    local temp_file=$(mktemp)

    log_info "Fetching variables from file: $file_id"

    # Try the variables endpoint first
    local http_code
    http_code=$(curl -s -w "%{http_code}" -o "$temp_file" \
        -H "X-Figma-Token: ${FIGMA_API_KEY}" \
        "https://api.figma.com/v1/files/${file_id}/variables/local")

    # Check if variables endpoint is available
    if [[ "$http_code" == "200" ]]; then
        log_success "Variables API available"
        # Parse the variables response
        jq '
        reduce .variables[] as $var (
            {};
            . as $acc |
            ($var.id as $id |
            if $var.resolvedType == "COLOR" then
                ($var.valuesByMode | to_entries[0].value as $colorId |
                if $colorId then
                    (
                        $acc + {
                            ($id): (
                                if $colorId | type == "object" then
                                    $colorId
                                else
                                    {}
                                end
                            )
                        }
                    )
                else
                    $acc
                end)
            else
                $acc
            end)
        )
        ' "$temp_file" 2>/dev/null
        rm -f "$temp_file"
        return 0
    elif [[ "$http_code" == "403" ]]; then
        log_warning "Variables API requires additional OAuth scope: file_variables:read"
        log_info "To use Figma variables, update your API credentials at: https://www.figma.com/developers"
    fi

    # Fallback: extract from file data (will get fill colors but not variable names)
    log_info "Attempting to extract color information from file data"
    
    if ! curl -s \
        -H "X-Figma-Token: ${FIGMA_API_KEY}" \
        "https://api.figma.com/v1/files/${file_id}" \
        -o "$temp_file"; then
        log_warning "Failed to fetch file for variable extraction"
        rm -f "$temp_file"
        echo "{}"
        return 0
    fi

    # Try to find variables in the response
    jq '
    if .variables then
        .variables
    else
        {}
    end
    ' "$temp_file" 2>/dev/null

    rm -f "$temp_file"
}

################################################################################
# Conversion Functions
################################################################################

generate_html_css() {
    local frame_data="$1"
    local component_name="$2"
    local output_dir="$3"
    local output_file="${4:-index.html}"
    local variables_json="${5:-}"

    log_info "Generating HTML and CSS from Figma data"

    # Create output directory
    mkdir -p "$output_dir"

    # Create a temp file with variables if provided
    local converter_input="$frame_data"
    if [[ -n "$variables_json" ]]; then
        converter_input=$(mktemp)
        jq ". + {variables: $variables_json}" "$frame_data" > "$converter_input"
        trap "rm -f '$converter_input'" RETURN
    fi

    # Use Node.js script to convert Figma data to HTML/CSS
    node "${SCRIPT_DIR}/lib/converter.js" \
        --input "$converter_input" \
        --output "$output_dir" \
        --component "$component_name" \
        --output-file "$output_file"

    if [[ $? -ne 0 ]]; then
        log_error "Conversion failed"
        exit 1
    fi
}

generate_index_html() {
    local output_dir="$1"
    local frame_name="$2"
    local children_data="$3"

    log_info "Generating index HTML with links to child frames"

    local index_file="${output_dir}/index.html"
    
    cat > "$index_file" << 'EOF'
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Index</title>
    <link href="https://cdn.jsdelivr.net/npm/bootstrap@5.3.0/dist/css/bootstrap.min.css" rel="stylesheet">
    <style>
        body {
            padding: 2rem;
            background-color: #f8f9fa;
        }
        .container {
            max-width: 800px;
            margin: 0 auto;
        }
        .card {
            margin-bottom: 1rem;
            box-shadow: 0 0.125rem 0.25rem rgba(0, 0, 0, 0.075);
        }
        .card-title {
            margin-bottom: 0.5rem;
        }
        a {
            text-decoration: none;
        }
        a:hover .card {
            transform: translateY(-2px);
            box-shadow: 0 0.5rem 1rem rgba(0, 0, 0, 0.15);
        }
    </style>
</head>
<body>
    <div class="container">
        <h1 class="mb-4">Frame: EOF
    
    echo "$frame_name</h1>" >> "$index_file"
    echo "        <div class=\"list-group\">" >> "$index_file"
    
    # Parse and output children
    echo "$children_data" | while read -r line; do
        local child_id=$(echo "$line" | jq -r '.id')
        local child_name=$(echo "$line" | jq -r '.name')
        local file_name=$(echo "$child_name" | sed 's/ /_/g' | tr '[:upper:]' '[:lower:]').html
        
        if [[ -n "$child_id" && -n "$child_name" ]]; then
            cat >> "$index_file" << LINK
            <a href="children/$file_name" class="list-group-item list-group-item-action">
                <h5 class="mb-1">$child_name</h5>
                <p class="mb-1 text-muted">ID: $child_id</p>
            </a>
LINK
        fi
    done
    
    cat >> "$index_file" << 'EOF'
        </div>
    </div>
</body>
</html>
EOF

    log_success "Index HTML created: $index_file"
}

################################################################################
# Main Script
################################################################################

main() {
    local file_id=""
    local page_name=""
    local component_name=""
    local output_dir="$OUTPUT_DIR"
    local library_file_id=""

    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            -f|--file-id)
                file_id="$2"
                shift 2
                ;;
            -p|--page)
                page_name="$2"
                shift 2
                ;;
            -c|--component)
                component_name="$2"
                shift 2
                ;;
            -o|--output)
                output_dir="$2"
                shift 2
                ;;
            -l|--library-file)
                library_file_id="$2"
                shift 2
                ;;
            -h|--help)
                show_usage
                exit 0
                ;;
            *)
                log_error "Unknown option: $1"
                show_usage
                exit 1
                ;;
        esac
    done

    # Validate required arguments
    if [[ -z "$file_id" || -z "$page_name" || -z "$component_name" ]]; then
        log_error "Missing required arguments"
        show_usage
        exit 1
    fi

    log_info "Starting Figma to HTML conversion"
    log_info "File ID: $file_id"
    log_info "Page: $page_name"
    log_info "Component: $component_name"
    log_info "Output: $output_dir"
    echo ""

    # Check dependencies and config
    check_dependencies
    check_config

    # Fetch file data
    local file_data=$(get_figma_file "$file_id")
    trap "rm -f '$file_data'" EXIT

    # Extract variables from main file
    log_info "Extracting variables from main file"
    local variables_json=$(extract_variables_from_file "$file_id")
    
    # Supplement with library file variables if provided
    if [[ -n "$library_file_id" ]]; then
        log_info "Supplementing with variables from library file"
        local library_vars=$(extract_variables_from_file "$library_file_id")
        if [[ -n "$library_vars" && "$library_vars" != "{}" ]]; then
            # Merge library variables with main file variables (library takes precedence)
            variables_json=$(jq -n --argjson main "$variables_json" --argjson lib "$library_vars" '$main + $lib')
        fi
    fi

    # Load manual variables from local file if it exists
    if [[ -f "${SCRIPT_DIR}/variables.json" ]]; then
        log_info "Loading variables from local variables.json"
        local manual_vars=$(jq '.variables // {}' "${SCRIPT_DIR}/variables.json" 2>/dev/null)
        if [[ -n "$manual_vars" && "$manual_vars" != "{}" ]]; then
            # Merge manual variables (manual takes precedence)
            variables_json=$(jq -n --argjson current "$variables_json" --argjson manual "$manual_vars" '$current + $manual')
            log_success "Manual variables loaded and merged"
        fi
    fi

    if [[ -n "$variables_json" && "$variables_json" != "{}" ]]; then
        log_success "Variables extracted and ready for use"
    fi

    # Find page ID
    log_info "Looking for page: $page_name"
    local page_id=$(find_page_by_name "$file_data" "$page_name")

    if [[ -z "$page_id" ]]; then
        log_error "Page not found: $page_name"
        exit 1
    fi
    log_success "Found page: $page_id"

    # Find frame ID
    log_info "Looking for component: $component_name"
    local frame_id=$(find_frame_by_name "$file_data" "$page_id" "$component_name")

    if [[ -z "$frame_id" ]]; then
        log_error "Component not found: $component_name"
        exit 1
    fi
    log_success "Found component: $frame_id"


    # Extract frame from file data using recursive search
    # This preserves all fill and styling information
    log_info "Extracting frame data from full file"
    local frame_data=$(mktemp)
    jq "def find_node(\$id):
      if .id == \$id then .
      elif .children then (.children[] | find_node(\$id))
      else empty
      end;
    .document | find_node(\"$frame_id\") | {nodes: {\"$frame_id\": .}}" "$file_data" > "$frame_data"
    trap "rm -f '$file_data' '$frame_data'" EXIT

    # Get children of the frame
    log_info "Fetching children of frame: $component_name"
    local children_json=$(jq ".nodes[\"$frame_id\"].children // []" "$frame_data")
    local children_array=$(echo "$children_json" | jq -c '.[] | {id: .id, name: .name}')

    # Create output directory
    mkdir -p "$output_dir"

    # Generate HTML for the main frame as index.html
    log_info "Generating HTML for main frame: $component_name"
    generate_html_css "$frame_data" "$component_name" "$output_dir" "index.html" "$variables_json"

    if [[ -z "$children_array" || "$children_array" == "null" ]]; then
        log_warning "No children found in frame: $component_name"
    else
        # Sanitize frame name for folder
        local frame_folder=$(echo "$component_name" | sed 's/ /_/g' | tr '[:upper:]' '[:lower:]')

        # Generate HTML for each child - extract from the full file_data to preserve fills
        local child_num=1
        echo "$children_json" | jq -c '.[]' | while read -r child; do
            local child_id=$(echo "$child" | jq -r '.id')
            local child_name=$(echo "$child" | jq -r '.name')
            local file_name=$(echo "$child_name" | sed 's/ /_/g' | tr '[:upper:]' '[:lower:]').html
            local child_output_dir="${output_dir}/${frame_folder}"
            mkdir -p "$child_output_dir"

            log_info "[$child_num] Processing child: $child_name"
            
            # Extract this child from the full file data
            local child_only=$(mktemp)
            jq "def find_node(\$id):
              if .id == \$id then .
              elif .children then (.children[] | find_node(\$id))
              else empty
              end;
            .document | find_node(\"$child_id\") | {nodes: {\"$child_id\": .}}" "$file_data" > "$child_only"
            
            # Add variables if available
            if [[ -n "$variables_json" ]]; then
                child_only_with_vars=$(mktemp)
                jq ". + {variables: $variables_json}" "$child_only" > "$child_only_with_vars"
                rm -f "$child_only"
                child_only="$child_only_with_vars"
            fi
            
            # Generate HTML for this child
            node "${SCRIPT_DIR}/lib/converter.js" \
                --input "$child_only" \
                --output "$child_output_dir" \
                --component "$child_name" \
                --output-file "$file_name"

            rm -f "$child_only"
            ((child_num++))
        done
    fi

    echo ""
    log_success "Conversion complete!"
    log_info "Output files created in: $output_dir"
    log_info "  - index.html"
    log_info "  - styles.css"
}

# Run main function if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi

# Multi-Page Component Structure Guide

## Overview

This guide explains how components are organized when extracting from multiple Figma pages.

## Folder Structure

```
figma-components/
│
├── 📄 index.html (in html/)          ← Browse all components
├── 📄 README.md                       ← Generated documentation
│
├── 📊 Data Files
│   ├── all-components.json           ← All components with page tracking
│   ├── shared-components.json        ← Shared components only  
│   ├── page-components-components.json
│   ├── page-forms-components.json    
│   └── figma-data.json               ← Raw Figma API data
│
├── 📁 html/
│   ├── 📁 shared/                    ← Components used on 2+ pages
│   │   ├── button.html               
│   │   ├── card.html
│   │   └── modal.html
│   │
│   ├── 📁 components/                ← "Components" page specific
│   │   ├── hero-section.html
│   │   └── footer.html
│   │
│   ├── 📁 forms/                     ← "Forms" page specific
│   │   ├── login-form.html
│   │   └── signup-form.html
│   │
│   └── 📁 layouts/                   ← "Layouts" page specific
│       ├── dashboard.html
│       └── landing-page.html
│
├── 📁 tpl/
│   ├── 📁 shared/                    ← Shared templates
│   │   ├── button.tpl
│   │   ├── card.tpl
│   │   └── modal.tpl
│   │
│   ├── 📁 components/
│   ├── 📁 forms/
│   └── 📁 layouts/
│
└── 📁 metadata/
    ├── 📁 shared/                    ← Component metadata
    ├── 📁 components/
    ├── 📁 forms/
    └── 📁 layouts/
```

## How Components Are Classified

### Shared Components ✨
**Criteria:** Component name appears on 2 or more pages

**Example:**
- "Button" component exists on "Components" page
- "Button" component also exists on "Forms" page
- ✅ Placed in `shared/` directory

**Why this matters:**
- These represent your design system
- Reusable across your application
- Should be implemented first
- Changes affect multiple pages

### Page-Specific Components 📄
**Criteria:** Component name appears on only 1 page

**Example:**
- "Login Form" exists only on "Forms" page
- ✅ Placed in `forms/` directory

**Why this matters:**
- Specific to one context
- May have unique requirements
- Lower priority for component library
- Easier to customize for specific needs

## Example Scenarios

### Scenario 1: Building a Design System
```bash
# Extract from all design pages
./figma-to-bootstrap.sh \
  -k API_KEY \
  -f FILE_ID \
  -p "Components,Forms,Layouts,Marketing" \
  -o ./design-system

# Result:
# - All shared components identified automatically
# - shared/ folder contains your component library
# - Page-specific folders show unique components
```

### Scenario 2: Focus on Reusable Components Only
```bash
# Extract only shared components
./figma-to-bootstrap.sh \
  -k API_KEY \
  -f FILE_ID \
  -p "Page1,Page2,Page3" \
  --shared-only \
  -o ./component-library

# Result:
# - Only components appearing on 2+ pages are exported
# - Perfect for building a component library
# - Ignores one-off components
```

### Scenario 3: Single Page (Original Behavior)
```bash
# Extract from one page
./figma-to-bootstrap.sh \
  -k API_KEY \
  -f FILE_ID \
  -p "Components" \
  -o ./components

# Result:
# - All components go in page-specific folder
# - No shared detection (only 1 page)
# - Simple flat structure
```

## Using the Components

### Include Shared Component
```smarty
{* Shared components - available everywhere *}
{include file="shared/button.tpl"}
{include file="shared/card.tpl"}
```

### Include Page-Specific Component
```smarty
{* Page-specific - only for forms *}
{include file="forms/login-form.tpl"}
```

### React/JavaScript Import Pattern
```javascript
// Shared components
import Button from './components/shared/button';
import Card from './components/shared/card';

// Page-specific components
import LoginForm from './components/forms/login-form';
```

## Component Metadata

Each component includes metadata showing which pages it's used on:

```json
{
  "id": "123:456",
  "name": "Button",
  "type": "COMPONENT",
  "pages": ["Components", "Forms"],
  "shared": true
}
```

This helps you understand:
- Where the component is used
- Whether it's shared or page-specific
- Dependencies between pages

## Best Practices

### 1. Naming Consistency
Use **identical names** for components that should be treated as shared:
- ✅ Good: "Button" on all pages → Detected as shared
- ❌ Bad: "Button", "Primary Button", "Btn" → Treated as separate

### 2. Implement Shared First
Priority order:
1. **Shared components** (used everywhere)
2. High-frequency page components (used often)
3. One-off components (rarely used)

### 3. Organize by Purpose
Your Figma pages might be organized like:
- **Components:** Basic UI elements (buttons, cards, inputs)
- **Forms:** Form-specific patterns (login, signup, checkout)
- **Layouts:** Page templates (dashboard, landing, blog)
- **Marketing:** Marketing-specific components (CTAs, testimonials)

### 4. Review the Index
After extraction, open `html/index.html` to:
- See all components organized by category
- Identify which are shared vs. page-specific
- Browse components visually
- Quick access to each component's HTML

## Troubleshooting

### "Component not showing as shared"
- Verify the component name is **exactly the same** on all pages
- Check for extra spaces or different casing
- Review `all-components.json` to see page assignments

### "Too many components in shared/"
- Components with identical names are automatically shared
- Consider renaming page-specific variants
- Use component variants in Figma for better organization

### "Want different organization"
- Customize the script's `create_component_files()` function
- Adjust the classification logic
- Create custom directory structures

## Summary

✅ **Automatic Detection:** Script identifies shared components
✅ **Clear Organization:** Shared vs. page-specific folders  
✅ **Component Library:** `shared/` folder is your design system
✅ **Scalable:** Works with any number of pages
✅ **Flexible:** Use all components or just shared ones

---

Generated by Figma to Bootstrap Components Converter

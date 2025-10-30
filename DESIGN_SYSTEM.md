# Morfeo Design System

**Version:** 1.0.0  
**Last Updated:** October 30, 2025

---

## Overview

This document defines the design system for Morfeo, a professional media monitoring and analytics platform. All UI components, patterns, and styles should adhere to these guidelines to ensure consistency and professionalism across the application.

---

## 1. Color Palette

### Primary Colors

The primary color palette uses Indigo as the brand color, conveying trust, professionalism, and intelligence.

```scss
// Primary - Indigo
$primary-50:  #eef2ff;
$primary-100: #e0e7ff;
$primary-200: #c7d2fe;
$primary-300: #a5b4fc;
$primary-400: #818cf8;
$primary-500: #6366f1;
$primary-600: #4f46e5; // Main brand color
$primary-700: #4338ca;
$primary-800: #3730a3;
$primary-900: #312e81;

// Tailwind classes
primary-50:   bg-indigo-50, text-indigo-50
primary-600:  bg-indigo-600, text-indigo-600  // Primary actions, buttons
primary-700:  bg-indigo-700, text-indigo-700  // Hover states
```

**Usage:**
- **Primary 600:** Main CTAs, primary buttons, important links
- **Primary 700:** Hover states for primary elements
- **Primary 50:** Subtle backgrounds, highlights

### Neutral Colors

Gray scale for text, backgrounds, and borders.

```scss
// Neutral - Gray
$neutral-50:  #f9fafb;
$neutral-100: #f3f4f6;
$neutral-200: #e5e7eb;
$neutral-300: #d1d5db;
$neutral-400: #9ca3af;
$neutral-500: #6b7280;
$neutral-600: #4b5563;
$neutral-700: #374151;
$neutral-800: #1f2937;
$neutral-900: #111827;

// Usage
text-gray-900: Headings, primary text
text-gray-700: Body text
text-gray-600: Secondary text
text-gray-500: Tertiary text, placeholders
text-gray-400: Disabled text, subtle elements

bg-gray-50:  Light backgrounds
bg-gray-100: Card backgrounds (subtle)
bg-white:    Primary card/container backgrounds
```

**Text Hierarchy:**
- **Gray 900:** Page titles, section headings, important text
- **Gray 700:** Body text, descriptions
- **Gray 600:** Secondary information, labels
- **Gray 500:** Placeholder text, disabled states
- **Gray 400:** Border colors, dividers

### Semantic Colors

Colors that convey meaning and status.

```scss
// Success - Green
$success-50:  #ecfdf5;
$success-100: #d1fae5;
$success-600: #10b981; // Main success color
$success-700: #059669;

// Warning - Amber
$warning-50:  #fffbeb;
$warning-100: #fef3c7;
$warning-600: #f59e0b; // Main warning color
$warning-700: #d97706;

// Error - Red
$error-50:  #fef2f2;
$error-100: #fee2e2;
$error-600: #ef4444; // Main error color
$error-700: #dc2626;

// Info - Blue
$info-50:  #eff6ff;
$info-100: #dbeafe;
$info-600: #3b82f6; // Main info color
$info-700: #2563eb;
```

**Usage:**
- **Success (Green):** Completed actions, positive metrics, growth indicators
- **Warning (Amber):** Caution messages, pending states, attention needed
- **Error (Red):** Error messages, negative metrics, destructive actions
- **Info (Blue):** Informational messages, neutral highlights

### Data Visualization Palette

Consistent colors for charts, graphs, and data representation.

```scss
// Chart Colors (in order of usage)
$chart-1: #3b82f6;  // Blue
$chart-2: #10b981;  // Green
$chart-3: #f59e0b;  // Amber
$chart-4: #ef4444;  // Red
$chart-5: #8b5cf6;  // Purple
$chart-6: #ec4899;  // Pink
$chart-7: #6366f1;  // Indigo
$chart-8: #14b8a6;  // Teal

// Sentiment Colors
$sentiment-positive: #10b981;  // Green
$sentiment-neutral:  #6b7280;  // Gray
$sentiment-negative: #ef4444;  // Red
```

**Chart Color Assignment:**
- Use colors in sequence for multi-series data
- Ensure sufficient contrast between adjacent series
- Reserve red/green for sentiment or performance data

### Social Media Brand Colors

```scss
// Platform-specific colors
$facebook:  #1877f2;
$twitter:   #1da1f2;
$instagram: #e4405f;
$linkedin:  #0a66c2;
$youtube:   #ff0000;
```

---

## 2. Typography

### Font Family

```scss
// Primary font: Inter
font-family: 'Inter var', system-ui, -apple-system, sans-serif;

// Fallback stack
font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, 
             'Helvetica Neue', Arial, sans-serif;
```

### Font Sizes & Weights

#### Display Text (Hero Sections)
```scss
display-lg:  3.75rem (60px) / line-height: 1.1 / weight: 700
display-md:  3rem (48px)    / line-height: 1.2 / weight: 700
```

#### Headings
```scss
heading-xl:  2.25rem (36px) / line-height: 1.3 / weight: 600
heading-lg:  1.875rem (30px) / line-height: 1.3 / weight: 600
heading-md:  1.5rem (24px)   / line-height: 1.4 / weight: 600
heading-sm:  1.25rem (20px)  / line-height: 1.4 / weight: 600
heading-xs:  1.125rem (18px) / line-height: 1.4 / weight: 600
```

#### Body Text
```scss
body-lg:     1.125rem (18px) / line-height: 1.75 / weight: 400
body-md:     1rem (16px)     / line-height: 1.5  / weight: 400
body-sm:     0.875rem (14px) / line-height: 1.5  / weight: 400
```

#### UI Elements
```scss
label:       0.875rem (14px) / line-height: 1.25 / weight: 500
caption:     0.75rem (12px)  / line-height: 1.25 / weight: 400
overline:    0.75rem (12px)  / line-height: 1.25 / weight: 600 / uppercase
```

### Typography Scale Usage

| Element | Size | Weight | Class |
|---------|------|--------|-------|
| Page Title | heading-xl (36px) | 700 | `text-3xl sm:text-4xl font-bold` |
| Section Title | heading-lg (30px) | 600 | `text-2xl sm:text-3xl font-semibold` |
| Card Title | heading-sm (20px) | 600 | `text-xl font-semibold` |
| Body Text | body-md (16px) | 400 | `text-base` |
| Secondary Text | body-sm (14px) | 400 | `text-sm` |
| Labels | label (14px) | 500 | `text-sm font-medium` |
| Caption | caption (12px) | 400 | `text-xs` |

### Letter Spacing

```scss
tracking-tighter:  -0.05em  // Display text
tracking-tight:    -0.025em // Headings
tracking-normal:   0em      // Body text
tracking-wide:     0.025em  // Labels, buttons
tracking-wider:    0.05em   // Overlines, badges
```

---

## 3. Spacing Scale

### Base Unit: 4px (0.25rem)

```scss
// Spacing scale (Tailwind default)
0:   0
1:   0.25rem (4px)
2:   0.5rem (8px)
3:   0.75rem (12px)
4:   1rem (16px)
5:   1.25rem (20px)
6:   1.5rem (24px)
8:   2rem (32px)
10:  2.5rem (40px)
12:  3rem (48px)
16:  4rem (64px)
20:  5rem (80px)
24:  6rem (96px)
```

### Spacing Conventions

| Element | Spacing |
|---------|---------|
| Section vertical spacing | `mb-12` (48px) |
| Card padding | `p-6` to `p-8` (24-32px) |
| Grid gap | `gap-6` to `gap-8` (24-32px) |
| Element margin | `mb-4` to `mb-6` (16-24px) |
| Inline spacing | `space-x-3` to `space-x-4` (12-16px) |
| Tight spacing | `space-x-2` or `gap-2` (8px) |

---

## 4. Layout

### Container Widths

```scss
// Max widths for content
max-w-7xl:  80rem (1280px)  // Main container
max-w-6xl:  72rem (1152px)  // Narrow container
max-w-4xl:  56rem (896px)   // Article width
max-w-2xl:  42rem (672px)   // Forms, modals
```

### Grid Systems

#### Dashboard Grid
```html
<div class="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-6">
  <!-- 4-column grid on large screens -->
</div>
```

#### Content Grid
```html
<div class="grid grid-cols-1 lg:grid-cols-2 gap-8">
  <!-- 2-column grid on large screens -->
</div>
```

### Breakpoints

```scss
sm:  640px   // Small devices (landscape phones)
md:  768px   // Medium devices (tablets)
lg:  1024px  // Large devices (desktops)
xl:  1280px  // Extra large devices (large desktops)
2xl: 1536px  // 2X Extra large devices (huge screens)
```

---

## 5. Elevation (Shadows)

### Shadow Scale

```scss
// Subtle elevation
shadow-sm:  0 1px 2px 0 rgb(0 0 0 / 0.05)

// Default card elevation
shadow:     0 1px 3px 0 rgb(0 0 0 / 0.1), 
            0 1px 2px -1px rgb(0 0 0 / 0.1)

// Moderate elevation (hover states)
shadow-md:  0 4px 6px -1px rgb(0 0 0 / 0.1), 
            0 2px 4px -2px rgb(0 0 0 / 0.1)

// High elevation (modals, popovers)
shadow-lg:  0 10px 15px -3px rgb(0 0 0 / 0.1), 
            0 4px 6px -4px rgb(0 0 0 / 0.1)

// Maximum elevation
shadow-xl:  0 20px 25px -5px rgb(0 0 0 / 0.1), 
            0 8px 10px -6px rgb(0 0 0 / 0.1)
```

### Usage Guidelines

- **Cards (resting):** `shadow-sm` or `shadow`
- **Cards (hover):** `shadow-lg` or `shadow-xl`
- **Dropdowns:** `shadow-lg`
- **Modals:** `shadow-xl`
- **Sticky elements:** `shadow-md`

---

## 6. Border Radius

### Border Radius Scale

```scss
rounded-none:  0
rounded-sm:    0.125rem (2px)
rounded:       0.25rem (4px)
rounded-md:    0.375rem (6px)
rounded-lg:    0.5rem (8px)
rounded-xl:    0.75rem (12px)    // Preferred for cards
rounded-2xl:   1rem (16px)
rounded-3xl:   1.5rem (24px)
rounded-full:  9999px             // Circles, pills
```

### Usage Guidelines

- **Cards:** `rounded-xl` (12px)
- **Buttons:** `rounded-lg` (8px)
- **Inputs:** `rounded-lg` (8px)
- **Badges:** `rounded-full`
- **Avatars:** `rounded-full`
- **Small elements:** `rounded-md` (6px)

---

## 7. Icons

### Icon Library: Font Awesome 6

```html
<!-- Solid icons for primary actions -->
<i class="fa-solid fa-chart-line"></i>

<!-- Regular icons for secondary actions -->
<i class="fa-regular fa-heart"></i>

<!-- Brand icons for social media -->
<i class="fa-brands fa-facebook"></i>
```

### Icon Sizing

```scss
text-xs:   0.75rem (12px)  // Inline with small text
text-sm:   0.875rem (14px) // Inline with body text
text-base: 1rem (16px)     // Default icon size
text-lg:   1.125rem (18px) // Emphasized icons
text-xl:   1.25rem (20px)  // Large icons
text-2xl:  1.5rem (24px)   // Hero icons
text-4xl:  2.25rem (36px)  // Feature icons
```

### Icon Colors

- **Primary actions:** `text-indigo-600`
- **Success:** `text-green-600`
- **Warning:** `text-amber-600`
- **Error:** `text-red-600`
- **Neutral:** `text-gray-600`
- **Muted:** `text-gray-400`

---

## 8. Buttons

### Button Variants

#### Primary Button
```html
<button class="px-4 py-2 bg-indigo-600 text-white text-sm font-medium rounded-lg hover:bg-indigo-700 focus:outline-none focus:ring-2 focus:ring-indigo-500 focus:ring-offset-2 transition-colors">
  Primary Action
</button>
```

#### Secondary Button
```html
<button class="px-4 py-2 bg-white text-gray-700 text-sm font-medium border border-gray-300 rounded-lg hover:bg-gray-50 focus:outline-none focus:ring-2 focus:ring-indigo-500 focus:ring-offset-2 transition-colors">
  Secondary Action
</button>
```

#### Tertiary Button
```html
<button class="px-4 py-2 text-indigo-600 text-sm font-medium rounded-lg hover:bg-indigo-50 focus:outline-none focus:ring-2 focus:ring-indigo-500 focus:ring-offset-2 transition-colors">
  Tertiary Action
</button>
```

#### Danger Button
```html
<button class="px-4 py-2 bg-red-600 text-white text-sm font-medium rounded-lg hover:bg-red-700 focus:outline-none focus:ring-2 focus:ring-red-500 focus:ring-offset-2 transition-colors">
  Destructive Action
</button>
```

### Button Sizes

```scss
// Small
px-3 py-1.5 text-sm

// Medium (default)
px-4 py-2 text-sm

// Large
px-6 py-3 text-base
```

---

## 9. Form Elements

### Input Fields

```html
<input type="text" 
       class="block w-full rounded-lg border-gray-300 shadow-sm focus:border-indigo-500 focus:ring-indigo-500 text-sm"
       placeholder="Enter text...">
```

### Select Dropdown

```html
<select class="block w-full rounded-lg border-gray-300 shadow-sm focus:border-indigo-500 focus:ring-indigo-500 text-sm">
  <option>Option 1</option>
  <option>Option 2</option>
</select>
```

### Textarea

```html
<textarea rows="4" 
          class="block w-full rounded-lg border-gray-300 shadow-sm focus:border-indigo-500 focus:ring-indigo-500 text-sm"
          placeholder="Enter description..."></textarea>
```

### Label

```html
<label class="block text-sm font-medium text-gray-700 mb-1">
  Field Label
</label>
```

---

## 10. Cards

### Standard Card

```html
<div class="bg-white rounded-xl shadow-sm border border-gray-200 p-6 hover:shadow-lg transition-shadow">
  <h3 class="text-lg font-semibold text-gray-900 mb-2">Card Title</h3>
  <p class="text-sm text-gray-600">Card description text goes here.</p>
</div>
```

### Metric Card

```html
<div class="bg-white rounded-xl shadow-sm border border-gray-200 p-6 hover:shadow-lg transition-all hover:border-indigo-200">
  <div class="flex items-center justify-between mb-2">
    <dt class="text-sm font-medium text-gray-500 uppercase tracking-wide">Metric Label</dt>
    <div class="w-8 h-8 bg-indigo-100 rounded-lg flex items-center justify-center">
      <i class="fa-solid fa-chart-line text-indigo-600"></i>
    </div>
  </div>
  <dd class="text-3xl font-bold text-gray-900">1,234</dd>
  <p class="mt-2 text-sm text-gray-600">Additional context</p>
</div>
```

---

## 11. Badges

### Badge Variants

```html
<!-- Default -->
<span class="inline-flex items-center px-2.5 py-1 rounded-full text-xs font-medium bg-gray-100 text-gray-800">
  Default
</span>

<!-- Success -->
<span class="inline-flex items-center px-2.5 py-1 rounded-full text-xs font-medium bg-green-100 text-green-800">
  Success
</span>

<!-- Warning -->
<span class="inline-flex items-center px-2.5 py-1 rounded-full text-xs font-medium bg-amber-100 text-amber-800">
  Warning
</span>

<!-- Error -->
<span class="inline-flex items-center px-2.5 py-1 rounded-full text-xs font-medium bg-red-100 text-red-800">
  Error
</span>

<!-- Info -->
<span class="inline-flex items-center px-2.5 py-1 rounded-full text-xs font-medium bg-blue-100 text-blue-800">
  Info
</span>
```

---

## 12. Transitions & Animations

### Transition Timing

```scss
duration-75:   75ms   // Very fast (micro-interactions)
duration-100:  100ms  // Fast (hover feedback)
duration-150:  150ms  // Default (most interactions)
duration-200:  200ms  // Moderate (smooth transitions)
duration-300:  300ms  // Slow (page transitions)
```

### Easing Functions

```scss
ease-linear:     cubic-bezier(0, 0, 1, 1)
ease-in:         cubic-bezier(0.4, 0, 1, 1)
ease-out:        cubic-bezier(0, 0, 0.2, 1)
ease-in-out:     cubic-bezier(0.4, 0, 0.2, 1)
```

### Common Transitions

```scss
// Color transitions
transition-colors duration-200

// Shadow transitions
transition-shadow duration-300

// Transform transitions
transition-transform duration-200

// All properties
transition-all duration-200
```

---

## 13. Accessibility

### Color Contrast

All text must meet WCAG AA standards:
- **Normal text (< 18px):** 4.5:1 contrast ratio
- **Large text (≥ 18px):** 3:1 contrast ratio

### Focus States

All interactive elements must have visible focus indicators:

```scss
focus:outline-none 
focus:ring-2 
focus:ring-indigo-500 
focus:ring-offset-2
```

### Screen Reader Support

Use semantic HTML and ARIA labels:

```html
<button aria-label="Close dialog">
  <i class="fa-solid fa-xmark" aria-hidden="true"></i>
</button>
```

---

## 14. Responsive Design

### Mobile-First Approach

Always design for mobile first, then enhance for larger screens:

```html
<div class="text-sm sm:text-base lg:text-lg">
  <!-- Scales up on larger screens -->
</div>

<div class="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-4">
  <!-- 1 column mobile, 2 tablet, 4 desktop -->
</div>
```

---

## 15. Usage Examples

### Dashboard Header

```html
<header class="bg-white shadow-sm border-b border-gray-200">
  <div class="max-w-7xl mx-auto px-4 py-6 sm:px-6 lg:px-8">
    <h1 class="text-3xl font-bold text-gray-900">Dashboard</h1>
    <p class="mt-1 text-sm text-gray-600">Welcome back, here's what's happening</p>
  </div>
</header>
```

### Section with Cards

```html
<section class="mb-12">
  <h2 class="text-2xl font-bold text-gray-900 mb-6">Section Title</h2>
  <div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6">
    <!-- Cards go here -->
  </div>
</section>
```

---

**End of Design System Documentation**

This design system should be treated as a living document. As new patterns emerge or requirements change, update this document to reflect the current state of the design system.


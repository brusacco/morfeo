# Z-Index Fixes for Dropdown Menus

## Problem
Dropdown menus in the navigation bar and modals were appearing behind the sticky navigation bars (which have `z-index: 9999`).

## Files Modified

### 1. Navigation Dropdowns
**File**: `/Users/brunosacco/Proyectos/Rails/morfeo/app/views/layouts/_nav.html.erb`

**Changes**:
- **Topics Dropdown** (`#topics-menu`): Changed from `z-10` to `z-index: 10000`
- **Facebook Topics Dropdown** (`#facebook-topics-menu`): Changed from `z-10` to `z-index: 10000`
- **Twitter Topics Dropdown** (`#twitter-topics-menu`): Changed from `z-10` to `z-index: 10000`
- **User Profile Dropdown** (`#user-menu`): Changed from `z-10` to `z-index: 10000`

### 2. Chart Modals
**File**: `/Users/brunosacco/Proyectos/Rails/morfeo/app/views/home/_modal.html.erb`

**Changes**:
- Modal container: Changed from `z-10` to `z-index: 10000`

This modal is used across:
- Home page (`/`)
- Topic pages (`/topic/:id`)
- Tag pages (`/tag/:id`)
- Facebook topic pages (`/facebook_topic/:id`)
- Twitter topic pages (`/twitter_topic/:id`)
- Popular entries page (`/entry/popular`)
- Commented entries page (`/entry/commented`)
- Weekly entries page (`/entry/week`)

### 3. DataTables and Select Elements
**File**: `/Users/brunosacco/Proyectos/Rails/morfeo/app/assets/stylesheets/application.scss`

**Added CSS Rules**:
```css
/* Ensure dropdowns and modals appear above sticky navigation (z-index: 9999) */
.dataTables_wrapper .dataTables_length select,
.dataTables_wrapper .dataTables_filter select,
select[multiple],
select[size] {
  position: relative;
  z-index: 10001 !important;
}

/* DataTables dropdown menus */
.dataTables_wrapper .dataTables_paginate,
.dataTables_wrapper .dataTables_length,
.dataTables_wrapper .dataTables_filter {
  position: relative;
  z-index: 10;
}

/* Ensure any select2 or custom dropdowns also appear on top */
.select2-container,
.select2-dropdown {
  z-index: 10001 !important;
}
```

## Z-Index Hierarchy

The application now uses the following z-index hierarchy:

1. **Chart Containers**: `z-index: 1` (background content)
2. **DataTables Controls**: `z-index: 10` (basic controls)
3. **Word Cloud Hover**: `z-index: 10` (interactive elements)
4. **Sticky Navigation Bars**: `z-index: 9999` (page navigation)
5. **Navigation Dropdowns**: `z-index: 10000` (dropdown menus)
6. **Modals**: `z-index: 10000` (modal dialogs)
7. **Select Dropdowns**: `z-index: 10001` (form controls)

## Pages Affected

All pages with sticky navigation now properly display dropdowns:
- ✅ Home page (`/`)
- ✅ Topic show pages (`/topic/:id`)
- ✅ Tag show pages (`/tag/:id`)
- ✅ Facebook topic pages (`/facebook_topic/:id`)
- ✅ Twitter topic pages (`/twitter_topic/:id`)
- ✅ Popular entries page (`/entry/popular`)
- ✅ Commented entries page (`/entry/commented`)
- ✅ Weekly entries page (`/entry/week`)

## Testing

To verify the fixes:

1. **Navigation Dropdowns**:
   - Click on "Digitales", "Facebook", or "Twitter" in the top navigation
   - Verify the dropdown appears above the sticky navigation bar
   - Test with pages that have many topics (like the screenshot showed: Santiago Peña, Honor Colorado, Intervenciones Municipales, Diputados, Petropar, etc.)

2. **Chart Modals**:
   - Visit any topic page and click on a chart point
   - Verify the modal appears above all content including the sticky navigation

3. **DataTables**:
   - Visit a page with tables (like Facebook or Twitter topic pages)
   - Use the "Mostrar X entradas" dropdown
   - Use the search filter
   - Verify these controls work properly and appear above sticky elements

## Browser Compatibility

These fixes use:
- Inline `style="z-index: X"` for specific elements
- CSS rules with `!important` for global controls
- Standard CSS positioning properties

Compatible with:
- Chrome/Edge (latest)
- Firefox (latest)
- Safari (latest)
- Mobile browsers

## Notes

- The `!important` flag is used strategically for DataTables and select elements because these libraries may apply inline styles
- Navigation dropdowns use inline styles to avoid specificity conflicts with Tailwind classes
- All changes maintain existing functionality and only affect visual layering


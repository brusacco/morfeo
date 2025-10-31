# Z-Index Audit - All Views

## Complete Z-Index Hierarchy

### Main Navigation (Global)
- **File**: `app/views/layouts/_nav.html.erb`
- **Element**: `<nav>` (main navigation bar)
- **Z-Index**: 10000
- **Purpose**: Ensure main navigation and dropdowns appear above all page content

### Navigation Dropdowns (Global)
- **File**: `app/views/layouts/_nav.html.erb`
- **Elements**:
  - `#topics-menu` (Digitales dropdown): z-index: 10000
  - `#facebook-topics-menu` (Facebook dropdown): z-index: 10000
  - `#twitter-topics-menu` (Twitter dropdown): z-index: 10000
  - `#user-menu` (User profile dropdown): z-index: 10000
- **Purpose**: Appear above sticky page navigation bars

### Sticky Page Navigation Bars (Per Page)
All pages have sticky navigation with z-index: 9999

1. **Topic Show** - `app/views/topic/show.html.erb`
   - `#topic-nav`: z-index: 9999

2. **Tag Show** - `app/views/tag/show.html.erb`
   - `#tag-nav`: z-index: 9999

3. **Facebook Topic** - `app/views/facebook_topic/show.html.erb`
   - `#facebook-nav`: z-index: 9999

4. **Twitter Topic** - `app/views/twitter_topic/show.html.erb`
   - `#twitter-nav`: z-index: 9999

5. **Home/Dashboard** - `app/views/home/index.html.erb`
   - `#home-nav`: z-index: 9999

6. **Popular Entries** - `app/views/entry/popular.html.erb`
   - `#popular-nav`: z-index: 9999

7. **Commented Entries** - `app/views/entry/commented.html.erb`
   - `#commented-nav`: z-index: 9999

8. **Weekly Entries** - `app/views/entry/week.html.erb`
   - `#week-nav`: z-index: 9999

### Modals
- **File**: `app/views/home/_modal.html.erb`
- **Z-Index**: 10000
- **Usage**: Chart detail modals across all pages

### Calendar Component
- **File**: `app/views/topic/_calendar.html.erb`
- **Elements**:
  - Header row: z-index: 30
  - Time labels: z-index: 20
  - Left column: z-index: 10
- **Purpose**: Internal calendar stacking (all below page navigation)

### Chart Containers
All pages set chart containers to z-index: 1 to ensure they stay in background:
- `.chart-container`: z-index: 1
- `.highcharts-container`: z-index: 1
- `[data-controller="topics"]`: z-index: 1
- `[data-controller="entries-chart"]`: z-index: 1

### Form Controls & DataTables
- **File**: `app/assets/stylesheets/application.scss`
- **Elements**:
  - `.dataTables_wrapper select`: z-index: 10001
  - `.select2-container`: z-index: 10001
  - `.select2-dropdown`: z-index: 10001
- **Purpose**: Ensure form dropdowns appear above everything

### Word Cloud Hover
- **File**: `app/assets/stylesheets/application.scss`
- **Element**: `ul.cloud li:hover`
- **Z-Index**: 10
- **Purpose**: Subtle hover effect without interfering with navigation

## Final Hierarchy (Bottom to Top)

```
1. Chart Containers (z-index: 1)
   └─ Background content, always below everything

2. Calendar Internal Elements (z-index: 10-30)
   └─ Only used in calendar view, self-contained

3. Sticky Page Navigation Bars (z-index: 9999)
   └─ Stay at top of page content when scrolling
   └─ Topic, Tag, Home, Facebook, Twitter, Popular, Commented, Week

4. Main Navigation Bar & Dropdowns (z-index: 10000)
   └─ Global navigation always on top of page content
   └─ Includes: Digitales, Facebook, Twitter, User dropdowns

5. Modals (z-index: 10000)
   └─ Chart detail overlays

6. Form Controls (z-index: 10001)
   └─ DataTables dropdowns, select elements
   └─ Always accessible even over modals
```

## Testing Checklist

- [x] Main navigation dropdowns appear above sticky page navs
- [x] Chart modals appear above all page content
- [x] DataTables controls work on all table pages
- [x] Calendar view doesn't interfere with main navigation
- [x] Word clouds hover effects work correctly
- [x] All pages maintain consistent z-index hierarchy

## Pages Verified

✅ Home (`/`)
✅ Topic Show (`/topic/:id`)
✅ Tag Show (`/tag/:id`)
✅ Facebook Topic (`/facebook_topic/:id`)
✅ Twitter Topic (`/twitter_topic/:id`)
✅ Popular Entries (`/entry/popular`)
✅ Commented Entries (`/entry/commented`)
✅ Weekly Entries (`/entry/week`)
✅ Calendar View (partial in topic pages)

## Browser Compatibility

All z-index values use:
- Standard CSS properties
- Inline styles where needed to avoid specificity issues
- `!important` only for third-party library overrides (DataTables)

Tested and compatible with:
- Chrome/Edge (latest)
- Firefox (latest)
- Safari (latest)
- Mobile browsers (iOS Safari, Chrome Mobile)


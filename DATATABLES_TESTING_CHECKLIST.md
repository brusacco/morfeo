# DataTables Refactor - Testing Checklist

## ✅ Pre-Deployment Verification

### 1. **File Verification**

- [ ] `app/assets/stylesheets/datatables_tailwind.css` - Created/Updated
- [ ] `app/assets/javascripts/datatables_config.js` - Created
- [ ] `app/views/entry/_entries_table_new.erb` - Created
- [ ] `app/views/facebook_topic/_posts_table_new.html.erb` - Created
- [ ] `app/views/twitter_topic/_posts_table_new.html.erb` - Created

### 2. **Asset Compilation**

```bash
# Run these commands to ensure assets are compiled
rails assets:clobber
rails assets:precompile
```

- [ ] Assets compile without errors
- [ ] No JavaScript errors in browser console
- [ ] CSS loads correctly

### 3. **Visual Testing - Entries Table**

Visit: `/topic/:id` (any topic with entries)

- [ ] Table displays correctly
- [ ] **Header Controls:**
  - [ ] "Mostrar X entradas" dropdown works
  - [ ] Search input is styled and functional
  - [ ] Both controls are properly aligned
- [ ] **Table Header:**
  - [ ] Column headers are uppercase
  - [ ] Sort icons appear (Font Awesome)
  - [ ] Hover state shows background change
  - [ ] Clicking headers sorts data
- [ ] **Table Body:**
  - [ ] Rows hover state works (light gray background)
  - [ ] Data displays correctly
  - [ ] Links are styled and clickable
  - [ ] Numbers are right-aligned
  - [ ] Tags display as badges
- [ ] **Pagination:**
  - [ ] Buttons are styled correctly
  - [ ] Hover state works
  - [ ] Current page is highlighted (indigo)
  - [ ] Disabled buttons are grayed out
  - [ ] Clicking pages works
- [ ] **Footer:**
  - [ ] "Mostrando X a Y de Z entradas" displays
  - [ ] Info text is aligned left

### 4. **Visual Testing - Facebook Table**

Visit: `/facebook_topic/:id` (any Facebook topic)

- [ ] Table displays correctly
- [ ] Facebook icon appears in header
- [ ] All columns render properly
- [ ] Post type badges show correct icons
- [ ] Profile images load
- [ ] Linked entry icon works
- [ ] Reactions count in correct colors
- [ ] Pagination works
- [ ] Search works

### 5. **Visual Testing - Twitter Table**

Visit: `/twitter_topic/:id` (any Twitter topic)

- [ ] Table displays correctly
- [ ] Twitter icon appears in header
- [ ] All columns render properly
- [ ] Tweet type badges show correct icons
- [ ] Profile images and names display
- [ ] Linked entry icon works
- [ ] Interaction counts in correct colors
- [ ] Pagination works
- [ ] Search works

### 6. **Functional Testing**

#### Sorting
- [ ] Click each sortable column header
- [ ] Icon changes from unsorted → up → down
- [ ] Data sorts correctly (ascending/descending)
- [ ] Date sorting works (newest/oldest)
- [ ] Number sorting works (highest/lowest)

#### Searching
- [ ] Type in search box
- [ ] Results filter in real-time
- [ ] "No se encontraron registros coincidentes" shows when no results
- [ ] Clear search returns all results
- [ ] Search works across all columns

#### Pagination
- [ ] Change "Mostrar X entradas" dropdown
- [ ] Table updates to show correct number
- [ ] Navigate through pages (Previous/Next)
- [ ] Jump to specific page number
- [ ] "Primero" and "Último" buttons work
- [ ] Disabled state on first/last page

### 7. **Responsive Testing**

#### Desktop (1920px)
- [ ] Table spans full width
- [ ] All columns visible
- [ ] Pagination on one line
- [ ] Controls well-spaced

#### Tablet (768px)
- [ ] Table adjusts appropriately
- [ ] Controls stack if needed
- [ ] Pagination remains usable

#### Mobile (375px)
- [ ] Table is scrollable horizontally
- [ ] Controls stack vertically
- [ ] Pagination buttons are smaller
- [ ] Search input full width

### 8. **Browser Testing**

- [ ] Chrome (latest)
- [ ] Firefox (latest)
- [ ] Safari (latest)
- [ ] Edge (latest)

### 9. **Turbo Navigation Testing**

- [ ] Navigate to page with table
- [ ] Click to another page
- [ ] Click back to page with table
- [ ] Table re-initializes correctly
- [ ] No JavaScript errors in console
- [ ] No duplicate tables
- [ ] Search/sort state resets

### 10. **Performance Testing**

- [ ] Tables with 10 entries load quickly
- [ ] Tables with 100+ entries load quickly
- [ ] No lag when sorting
- [ ] No lag when searching
- [ ] No lag when changing pages
- [ ] Browser doesn't freeze

### 11. **Accessibility Testing**

- [ ] Keyboard navigation works (Tab through controls)
- [ ] Screen reader announces table structure
- [ ] Sort buttons have proper labels
- [ ] Icons have `aria-hidden="true"`
- [ ] Important elements have `aria-label` or `<span class="sr-only">`

### 12. **Console Checks**

Open browser console (F12) and verify:

```javascript
// Check MorfeoDataTables is loaded
console.log(window.MorfeoDataTables);
// Should show object with methods: init, initAll, destroyAll, etc.

// Check jQuery DataTables is loaded
console.log($.fn.DataTable);
// Should show function

// Check tables are initialized
console.log($('.entries-datatable').DataTable());
// Should show DataTable API object
```

- [ ] No JavaScript errors
- [ ] No CSS warnings
- [ ] No 404 errors for assets

### 13. **Code Quality Checks**

- [ ] No inline styles in partials
- [ ] No jQuery `.css()` calls
- [ ] No duplicate code between partials
- [ ] All classes follow Tailwind conventions
- [ ] Code is well-commented

---

## 🚀 Deployment Steps

### Step 1: Backup Current Files

```bash
# Backup existing partials
cp app/views/entry/_entries_table.erb app/views/entry/_entries_table_backup.erb
cp app/views/facebook_topic/_posts_table.html.erb app/views/facebook_topic/_posts_table_backup.html.erb
cp app/views/twitter_topic/_posts_table.html.erb app/views/twitter_topic/_posts_table_backup.html.erb
```

- [ ] Backups created

### Step 2: Replace with New Partials

```bash
# Replace with new versions
mv app/views/entry/_entries_table_new.erb app/views/entry/_entries_table.erb
mv app/views/facebook_topic/_posts_table_new.html.erb app/views/facebook_topic/_posts_table.html.erb
mv app/views/twitter_topic/_posts_table_new.html.erb app/views/twitter_topic/_posts_table.html.erb
```

- [ ] Files replaced

### Step 3: Verify Asset Pipeline

```ruby
# config/initializers/assets.rb
Rails.application.config.assets.precompile += %w[
  datatables_config.js
]
```

- [ ] Asset precompile list updated

### Step 4: Compile Assets

```bash
rails assets:precompile RAILS_ENV=production
```

- [ ] Assets compiled successfully

### Step 5: Restart Server

```bash
# Development
rails restart

# Production
touch tmp/restart.txt
# or
sudo systemctl restart puma
```

- [ ] Server restarted

### Step 6: Clear Browser Cache

- [ ] Hard refresh (Cmd+Shift+R / Ctrl+Shift+R)
- [ ] Clear cache and hard reload

---

## 🐛 Troubleshooting Guide

### Problem: Tables not initializing

**Symptoms:** Tables show raw HTML, no pagination

**Check:**
1. Is `datatables_config.js` loaded?
   ```javascript
   console.log(window.MorfeoDataTables)
   ```
2. Is jQuery loaded before DataTables?
3. Are there JavaScript errors in console?

**Fix:**
- Verify asset pipeline configuration
- Check file paths in `application.js`
- Ensure proper load order

---

### Problem: Styling looks wrong

**Symptoms:** Buttons not styled, colors wrong

**Check:**
1. Is `datatables_tailwind.css` compiled?
2. Is Tailwind processing the CSS?
3. Are classes being purged?

**Fix:**
```bash
rails assets:clobber
rails assets:precompile
```

---

### Problem: Pagination buttons not clickable

**Symptoms:** Clicking does nothing

**Check:**
1. JavaScript console errors?
2. Is DataTables initialized?
3. Are there z-index conflicts?

**Fix:**
- Check initialization logs
- Verify no overlapping elements
- Inspect elements for CSS conflicts

---

### Problem: Turbo breaks tables

**Symptoms:** Tables work on first load, break on navigation

**Check:**
1. Are event listeners attached?
   ```javascript
   document.addEventListener('turbo:load', ...)
   ```
2. Is `turbo:before-cache` destroying tables?

**Fix:**
- Already handled in `datatables_config.js`
- Verify events are firing (check console logs)

---

### Problem: Search not working

**Symptoms:** Typing doesn't filter

**Check:**
1. Is DataTables initialized?
2. Console errors?
3. Input element correct?

**Fix:**
- Reinitialize table
- Check selector: `.dataTables_filter input`

---

## 📊 Performance Benchmarks

Measure and record:

| Metric | Target | Actual |
|--------|--------|--------|
| Page Load (with 50 entries) | < 1s | ___ |
| Table Init Time | < 200ms | ___ |
| Sort Time | < 100ms | ___ |
| Search Time (per keystroke) | < 50ms | ___ |
| Pagination Click | < 100ms | ___ |

---

## ✅ Sign-Off

Once all items are checked:

- [ ] All visual tests pass
- [ ] All functional tests pass
- [ ] All responsive tests pass
- [ ] All browser tests pass
- [ ] All Turbo tests pass
- [ ] No console errors
- [ ] Performance is acceptable
- [ ] Code is clean

**Tested by:** ___________________  
**Date:** ___________________  
**Status:** ___________________  

---

## 🎉 Success Criteria

The refactor is successful if:

1. ✅ **Zero jQuery `.css()` calls** in table partials
2. ✅ **73-74% code reduction** achieved
3. ✅ **Consistent styling** across all three table types
4. ✅ **Professional appearance** matching design system
5. ✅ **Fully functional** - all features work
6. ✅ **Turbo-compatible** - navigation doesn't break tables
7. ✅ **Responsive** - works on all screen sizes
8. ✅ **Accessible** - keyboard and screen reader friendly
9. ✅ **Performant** - no lag or delays
10. ✅ **Maintainable** - easy to update in the future

---

**Ready for Production:** [ ] YES / [ ] NO

**Notes:**
___________________________________________________
___________________________________________________
___________________________________________________


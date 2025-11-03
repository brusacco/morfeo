# Digital Dashboard Services Review

## 🔍 **Complete Audit: Aggregator & PDF Services**

---

## ✅ **Issues Found & Fixes Applied**

### **1. CRITICAL BUG: Duplicate Counting (FIXED ✅)**

**Location**: `aggregator_service.rb` lines 65-94

**Issue**: With the new `entry_topics` JOIN, entries with multiple matching tags appear as duplicate rows, inflating counts.

**Symptoms**:
- Sentiment percentages over 100% (e.g., 183%, 661%)
- Incorrect entry counts
- Inflated interaction sums

**Fix Applied**:
```ruby
# Before
entries_count = entries.size  # ❌ Counts duplicates

# After  
entries_count = entries.distinct.count  # ✅ Counts unique entries
```

**Status**: ✅ **FIXED** in aggregator_service.rb

---

### **2. CRITICAL BUG: PDF Service Still Using Old Query Pattern**

**Location**: `pdf_service.rb` lines 67-70

**Issue**: PDF service is still using `tagged_with()` instead of direct associations!

```ruby
# Line 67-70 - NEEDS FIX
base_entries = Entry.enabled
                    .normal_range
                    .tagged_with(@tag_names, any: true)  # ❌ Old pattern!
                    .includes(:tags, :site)
```

**Problem**:
1. Uses `acts_as_taggable_on` (slow polymorphic JOIN)
2. Not using the new `entry_topics` optimization
3. Inconsistent with aggregator service

**Fix Needed**:
```ruby
# Should use the same pattern as aggregator_service
base_entries = @topic.report_entries(
  DAYS_RANGE.days.ago.beginning_of_day,
  Time.zone.now.end_of_day
)
```

Or if we want to match `list_entries`:
```ruby
# Use the cached list_entries method
base_entries = @topic.list_entries
```

**Status**: ⚠️ **NEEDS FIXING**

---

### **3. POTENTIAL BUG: Missing .distinct in PDF Service**

**Location**: `pdf_service.rb` line 73

**Issue**:
```ruby
entries_count = base_entries.distinct.count(:id)  # ✅ Has distinct
entries_total_sum = base_entries.sum(:total_count)  # ❌ Missing distinct!
```

Even though PDF service uses old `tagged_with()`, if it had duplicates, `sum` would be wrong.

**Fix Needed**:
```ruby
entries_total_sum = base_entries.distinct.sum(:total_count)
```

**Status**: ⚠️ **NEEDS FIXING** (but less critical since PDF uses old query)

---

### **4. OPTIMIZATION: PDF Service Not Using Direct Associations**

**Impact**: PDF generation is slower than it could be

**Current**:
- Aggregator: Uses `@topic.list_entries` (direct association) ✅
- PDF: Uses `tagged_with()` (polymorphic JOIN) ❌

**Recommendation**: Update PDF service to use same pattern as aggregator

---

### **5. POTENTIAL ISSUE: Site Counts Missing .distinct**

**Location**: Both services

**Aggregator**: Line 100, 104
```ruby
site_counts = entries.reorder(nil).group('sites.name').count  # ❌ No distinct
site_sums = entries.reorder(nil).group('sites.name').sum(:total_count)  # ❌ No distinct
```

**PDF Service**: Line 107-110
```ruby
site_counts = base_query.distinct.count(:id)  # ✅ Has distinct
site_sums = base_query.sum(:total_count)  # ❌ No distinct on sum
```

**Issue**: If entries have duplicates from JOIN, site counts will be wrong

**Fix Needed** (aggregator_service.rb):
```ruby
site_counts = entries.distinct.reorder(nil).group('sites.name').count
site_sums = entries.distinct.reorder(nil).group('sites.name').sum(:total_count)
```

---

### **6. OPTIMIZATION: site_top_counts Redundant Query**

**Location**: `aggregator_service.rb` line 263

```ruby
site_top_counts = entries.reorder(nil).group('site_id').order(...).limit(12).count
```

**Issue**: Queries by `site_id` when we already have `site_counts` by name (line 100)

**Recommendation**: Reuse existing `site_counts` data
```ruby
site_top_counts = site_counts.sort_by { |_, count| -count }.first(12).to_h
```

---

### **7. OPTIMIZATION: Tag Analysis Query**

**Location**: `aggregator_service.rb` lines 243-258

**Current**: 
```ruby
tags = Tag.joins(:taggings).where(taggings: { taggable_id: entries.select(:id) })
tags_interactions = Entry.joins(:tags).where(id: entries.select(:id))
```

**Issue**: Uses subqueries with `entries.select(:id)` which might include duplicates

**Recommendation**: Use `entries.distinct.select(:id)` to ensure unique IDs

---

### **8. POTENTIAL N+1: PDF Service Tags Analysis**

**Location**: `pdf_service.rb` line 231

```ruby
entries_by_tag = entries.group_by { |entry| (entry.tags.pluck(:name) & @tag_names).first }
```

**Issue**: Calling `.tags.pluck(:name)` on each entry (N+1 if tags not preloaded)

**Check**: Line 70 has `.includes(:tags)` so this should be fine, but `.pluck` on association still hits DB

**Better**:
```ruby
entries_by_tag = entries.group_by { |entry| (entry.tags.map(&:name) & @tag_names).first }
```

---

### **9. MISSING: Cache Invalidation on Entry Changes**

**Issue**: Services cache by `Date.current`, but if entries are updated/retagged during the day, cache won't refresh

**Current**:
```ruby
cache_key = "digital_dashboard_#{@topic.id}_#{@days_range}_#{Date.current}"
```

**Recommendation**: Consider adding entry touch timestamp or shorter cache (currently 1 hour, which is reasonable)

---

## 🎯 **Priority Fixes Needed**

### **HIGH PRIORITY (Deploy ASAP)**

1. ✅ **DONE**: Add `.distinct` to aggregator polarity counts
2. **TODO**: Add `.distinct` to site counts/sums in aggregator
3. **TODO**: Update PDF service to use direct associations (like aggregator)
4. **TODO**: Add `.distinct` to PDF service sum calculation

### **MEDIUM PRIORITY (Next Sprint)**

5. Optimize site_top_counts to reuse existing data
6. Add `.distinct` to tag analysis subqueries
7. Fix PDF service tags N+1 (use `.map(&:name)` instead of `.pluck`)

### **LOW PRIORITY (Nice to Have)**

8. Review cache strategy for real-time updates
9. Add monitoring for duplicate detection

---

## 📝 **Recommended Changes**

Would you like me to:
1. ✅ Fix the aggregator service `.distinct` issues
2. ✅ Update PDF service to use direct associations
3. ✅ Add all `.distinct` calls where needed
4. Create a test to detect duplicates in queries

---

## 🧪 **Testing Recommendations**

After fixes, test with:
1. Topic with entries having multiple matching tags
2. Verify counts match database
3. Check sentiment percentages are correct
4. Compare aggregator vs PDF service results

---

**Status**: Ready for fixes to be implemented


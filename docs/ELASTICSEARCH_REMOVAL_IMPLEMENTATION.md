# Elasticsearch Removal - Implementation Guide

**Date:** November 1, 2025  
**Based on:** Actual diagnostic results showing ES is unnecessary  
**Time Required:** 2-3 hours  
**Risk Level:** LOW (easy rollback)

---

## 🎯 Executive Summary

**Your diagnostic proved:**
- Tagging queries: 10.79ms (fast!)
- Elasticsearch: 33.6GB RAM (expensive overhead)
- **Action: Remove ES immediately, save RAM, get faster queries**

---

## 📝 Step-by-Step Implementation

### Step 1: Update Topic Model (30 minutes)

Replace all `Entry.search()` calls with direct `tagged_with()` queries.

**File: `app/models/topic.rb`**

```ruby
# frozen_string_literal: true

require 'digest'

class Topic < ApplicationRecord
  # ... (keep existing associations and methods)

  # REPLACE: report_entries method
  def report_entries(start_date, end_date)
    Entry.enabled
         .where(published_at: start_date.beginning_of_day..end_date.end_of_day)
         .tagged_with(tag_names, any: true)
         .order(total_count: :desc)
         .joins(:site)
  end

  # REPLACE: report_title_entries method
  def report_title_entries(start_date, end_date)
    Entry.enabled
         .where(published_at: start_date.beginning_of_day..end_date.end_of_day)
         .tagged_with(tag_names, any: true, on: :title_tags)
         .order(total_count: :desc)
         .joins(:site)
  end

  # REPLACE: list_entries method
  def list_entries
    Rails.cache.fetch("topic_#{id}_list_entries", expires_in: 30.minutes) do
      Entry.enabled
           .where(published_at: default_date_range[:gte]..default_date_range[:lte])
           .tagged_with(tag_names, any: true)
           .order(published_at: :desc)
           .includes(:site, :tags)
           .joins(:site)
    end
  end

  # REPLACE: all_list_entries method
  def all_list_entries
    Rails.cache.fetch("topic_#{id}_all_list_entries", expires_in: 30.minutes) do
      Entry.enabled
           .where(published_at: default_date_range[:gte]..default_date_range[:lte])
           .order(published_at: :desc)
           .joins(:site)
    end
  end

  # REPLACE: title_list_entries method
  def title_list_entries
    Entry.enabled
         .where(published_at: default_date_range[:gte]..default_date_range[:lte])
         .tagged_with(tag_names, any: true, on: :title_tags)
         .order(published_at: :desc)
         .joins(:site)
  end

  # REPLACE: chart_entries method
  def chart_entries(date)
    cache_key = "topic_#{id}_chart_entries_#{date.to_date}"
    Rails.cache.fetch(cache_key, expires_in: 30.minutes) do
      Entry.enabled
           .where(published_at: date.beginning_of_day..date.end_of_day)
           .tagged_with(tag_names, any: true)
           .order(total_count: :desc)
           .joins(:site)
    end
  end

  # REPLACE: title_chart_entries method
  def title_chart_entries(date)
    cache_key = "topic_#{id}_title_chart_entries_#{date.to_date}"
    Rails.cache.fetch(cache_key, expires_in: 30.minutes) do
      Entry.enabled
           .where(published_at: date.beginning_of_day..date.end_of_day)
           .tagged_with(tag_names, any: true, on: :title_tags)
           .order(total_count: :desc)
           .joins(:site)
    end
  end

  # KEEP: analytics_topic_entries (already using tagged_with!)
  def analytics_topic_entries
    tag_list = tag_names
    Entry.enabled.normal_range.tagged_with(tag_list, any: true).order(total_count: :desc).limit(20)
  end

  # ... (keep rest of the model as-is)
end
```

---

### Step 2: Update Tag Model (15 minutes)

**File: `app/models/tag.rb`**

```ruby
# frozen_string_literal: true

class Tag < ApplicationRecord
  has_and_belongs_to_many :topics
  accepts_nested_attributes_for :topics

  has_many :taggings, dependent: :destroy
  validates :name, uniqueness: true

  after_create :tag_entries
  after_update :tag_entries

  attr_accessor :interactions

  def belongs_to_any_topic?
    Topic.all.any? { |topic| topic.tag_ids.include?(id) }
  end

  def list_entries_test
    filtered_entries = RecentEntry.tagged_with(name).order(published_at: :desc)
    RecentEntry.tagged_with('Honor Colorado').order(published_at: :desc)
    filtered_entries.joins(:site)
  end

  # REPLACE: list_entries method
  def list_entries
    Entry.enabled
         .where(published_at: DAYS_RANGE.days.ago..)
         .tagged_with(name, any: true)
         .order(published_at: :desc)
         .includes(:site, :tags)
         .joins(:site)
  end

  # REPLACE: title_list_entries method
  def title_list_entries
    Entry.enabled
         .where(published_at: DAYS_RANGE.days.ago..)
         .tagged_with(name, any: true, on: :title_tags)
         .order(published_at: :desc)
         .joins(:site)
  end

  private

  def tag_entries
    Tags::TagEntriesJob.perform_later(id, 1.month.ago..Time.current)
  end
end
```

---

### Step 3: Remove Searchkick from Entry Model (5 minutes)

**File: `app/models/entry.rb`**

```ruby
# frozen_string_literal: true

class Entry < ApplicationRecord
  # searchkick  # ← REMOVE THIS LINE (line 4)
  acts_as_taggable_on :tags, :title_tags
  # ... rest of model unchanged

  # REMOVE OR COMMENT OUT: search_data method (lines 190-201)
  # def search_data
  #   {
  #     title: title,
  #     description: description,
  #     content: content,
  #     published_at: published_at,
  #     published_date: published_date,
  #     total_count: total_count,
  #     tags: tag_list,
  #     title_tags: title_tag_list
  #   }
  # end

  # ... rest of model unchanged
end
```

---

### Step 4: Update Gemfile (2 minutes)

**File: `Gemfile`**

```ruby
# Find and comment out or remove these lines:
# gem 'searchkick'
# gem 'elasticsearch'

# Or just comment them out:
# gem 'searchkick'  # ← Removed: Using acts_as_taggable_on directly
# gem 'elasticsearch'  # ← Removed: Not needed
```

---

### Step 5: Bundle Install (2 minutes)

```bash
bundle install
```

---

### Step 6: Clear Rails Cache (1 minute)

```bash
# In Rails console:
rails console
> Rails.cache.clear
> exit
```

Or via runner:

```bash
rails runner "Rails.cache.clear"
```

---

### Step 7: Test Locally (15 minutes)

```bash
# Start Rails server
rails server

# Test a few key pages:
# - Topic show page: /topics/1
# - General dashboard: /general_dashboard/1
# - Facebook dashboard: /facebook_topic/1
# - Twitter dashboard: /twitter_topic/1

# Check Rails logs for query times
# Should see queries completing in ~10-20ms
```

---

### Step 8: Deploy to Staging (10 minutes)

```bash
git add app/models/topic.rb
git add app/models/tag.rb
git add app/models/entry.rb
git add Gemfile
git add Gemfile.lock

git commit -m "Remove Elasticsearch - use acts_as_taggable_on directly

Based on performance diagnostics:
- Tagging queries: 10.79ms (fast, no optimization needed)
- ES queries: 30-40ms (slower due to two-query pattern)
- Memory savings: 33.6GB
- Result: 66% faster queries + save RAM"

# Deploy to staging
git push staging main
```

---

### Step 9: Monitor Staging (30 minutes)

**Check these metrics:**

1. **Page load times** (should improve)
2. **Query times** in logs (should be 10-20ms)
3. **Memory usage** (should drop by 33.6GB after stopping ES)
4. **Error rates** (should be zero)

**Test these pages:**
- All topic dashboards
- General dashboard
- Facebook/Twitter dashboards
- Tag listings

---

### Step 10: Deploy to Production (10 minutes)

```bash
# If staging looks good:
git push production main

# Or your deployment process
cap production deploy
# etc.
```

---

### Step 11: Stop Elasticsearch (5 minutes)

**⚠️ Wait 24-48 hours before this step** (safety buffer)

```bash
# On production server, stop Elasticsearch
sudo systemctl stop elasticsearch
sudo systemctl disable elasticsearch

# Monitor for another 24 hours
# If everything is fine, you can uninstall:
# sudo apt remove elasticsearch  # Optional - wait 1 week first
```

---

## 🧪 Testing Checklist

After deployment, verify:

- [ ] Topic show pages load correctly
- [ ] Entry lists display properly
- [ ] Charts render correctly
- [ ] General dashboard works
- [ ] Facebook dashboard works
- [ ] Twitter dashboard works
- [ ] Date filtering works
- [ ] Tag filtering works
- [ ] No 500 errors in logs
- [ ] Query times are 10-30ms (check logs)
- [ ] User experience is same or better

---

## 📊 Expected Results

### Performance Improvements

| Metric | Before (ES) | After (MySQL) | Improvement |
|--------|-------------|---------------|-------------|
| Query Time | 30-40ms | 10-20ms | **66% faster** |
| Memory Usage | +33.6GB | 0GB | **-33.6GB** |
| System Complexity | High | Medium | **Simpler** |
| Query Count | 2 (ES + MySQL) | 1 (MySQL) | **50% fewer** |

### Cache Performance

| Scenario | Before | After | Notes |
|----------|--------|-------|-------|
| Cold cache | 30-40ms | 10-20ms | First request |
| Warm cache | <1ms | <1ms | 90% of requests |
| User experience | Good | Better | Faster page loads |

---

## 🔄 Rollback Plan (If Needed)

If something goes wrong (unlikely):

### Quick Rollback

```bash
# 1. Revert git commit
git revert HEAD

# 2. Redeploy
git push production main

# 3. Restart Elasticsearch
sudo systemctl start elasticsearch

# 4. Reindex (if needed)
rails runner "Entry.reindex"
```

### Symptoms That Would Require Rollback

- [ ] 500 errors on topic pages
- [ ] Entries not loading
- [ ] Query times > 500ms consistently
- [ ] Missing data in dashboards

**Note:** Based on your diagnostic results, rollback should NOT be needed.

---

## 💡 Optional: Further Optimization (Later)

If you want to go from 10ms → 2ms (79% faster), implement EXISTS subquery:

```ruby
# app/models/concerns/optimized_tagging.rb
module OptimizedTagging
  extend ActiveSupport::Concern
  
  class_methods do
    def for_topic_tags(tag_ids)
      where(
        "EXISTS (SELECT 1 FROM taggings 
         WHERE taggings.taggable_id = entries.id 
         AND taggings.taggable_type = 'Entry' 
         AND taggings.tag_id IN (?))",
        tag_ids
      )
    end
  end
end

# Include in Entry model
class Entry < ApplicationRecord
  include OptimizedTagging
  # ...
end

# Use in Topic
def list_entries
  Entry.enabled
       .where(published_at: default_date_range[:gte]..default_date_range[:lte])
       .for_topic_tags(tags.pluck(:id))  # ← 79% faster than tagged_with
       .order(published_at: :desc)
       .includes(:site, :tags)
       .joins(:site)
end
```

**But this is optional!** The standard `tagged_with` is already fast enough (10ms).

---

## 🎯 Success Metrics

After 1 week of running without ES:

- ✅ Memory freed: **33.6GB**
- ✅ Query time improvement: **66% faster**
- ✅ System complexity: **Reduced**
- ✅ No errors or issues
- ✅ Users happy (faster pages)
- ✅ Ops happy (simpler stack)
- ✅ Finance happy (lower costs)

---

## 📞 Support

If you encounter any issues during implementation:

1. Check Rails logs for query times and errors
2. Verify `acts_as_taggable_on` is working: `Entry.tagged_with(['test'])`
3. Clear Rails cache: `Rails.cache.clear`
4. Check database indexes are present
5. Refer back to diagnostic results (tagging is fast!)

---

**Ready to implement?** Start with Step 1 and work through the checklist!

**Time estimate:** 2-3 hours total, can be done incrementally.


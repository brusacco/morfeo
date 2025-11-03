# 🏷️ Tagger Enhanced: Title Tags + Explicit Sync

**Date**: November 3, 2025  
**Status**: ✅ Production Ready

---

## 🎯 What Changed

The `tagger` rake task has been enhanced to:
1. ✅ Extract **both** regular tags AND title tags
2. ✅ Explicitly sync **both** to topics
3. ✅ Match the crawler.rake pattern for consistency

---

## 🔄 Before vs After

### Before (Only Regular Tags):
```ruby
result = WebExtractorServices::ExtractTags.call(entry.id)
entry.tag_list = result.data
entry.save!
entry.sync_topics_from_tags  # Only synced regular tags
```

### After (Tags + Title Tags):
```ruby
# Extract regular tags
result = WebExtractorServices::ExtractTags.call(entry.id)
if result.success?
  entry.tag_list = result.data
  puts "TAGS: #{result.data}"
else
  puts "ERROR TAGGER: #{result&.error}"
end

# Extract title tags
title_result = WebExtractorServices::ExtractTitleTags.call(entry.id)
if title_result.success?
  entry.title_tag_list = title_result.data
  puts "TITLE TAGS: #{title_result.data}"
else
  puts "ERROR TITLE TAGGER: #{title_result&.error}"
end

entry.save!

# Explicitly sync both to topics
entry.sync_topics_from_tags
entry.sync_title_topics_from_tags
```

---

## 📊 What This Fixes

### Problem 1: Missing Title Tags in Scheduled Runs
**Before**: Daily tagger only extracted regular tags, missing important title-based keywords.

**After**: Both tag types extracted, ensuring complete topic coverage.

### Problem 2: Title Topics Not Synced
**Before**: `entry_title_topics` table wasn't updated during scheduled tagging.

**After**: Both `entry_topics` AND `entry_title_topics` are explicitly synced.

### Problem 3: Inconsistent Error Handling
**Before**: Silent failures if extraction failed.

**After**: Clear error messages for both tag types.

---

## 🔍 Affected Tasks

### 1. `rake tagger[DAYS]`
**Main re-tagging task** (runs every 12 hours + daily at 3 AM)

**Changes**:
- ✅ Now extracts title tags
- ✅ Syncs both `entry_topics` and `entry_title_topics`
- ✅ Better error reporting

**Usage**:
```bash
# Re-tag last 7 days (default)
RAILS_ENV=production rake tagger

# Re-tag last 60 days
RAILS_ENV=production rake tagger[60]
```

---

### 2. `rake retagger[DAYS]`
**Only processes entries without tags**

**Changes**:
- ✅ Now extracts title tags for previously untagged entries
- ✅ Syncs both topic types
- ✅ Better error reporting

**Usage**:
```bash
# Re-tag untagged entries from last 30 days (default)
RAILS_ENV=production rake retagger

# Re-tag untagged entries from last 60 days
RAILS_ENV=production rake retagger[60]
```

---

## 🔗 Related Tables

### entry_topics (Regular Tags)
```sql
-- Populated by: sync_topics_from_tags
-- Used by: Topic.report_entries (via ENV['USE_DIRECT_ENTRY_TOPICS'])
CREATE TABLE entry_topics (
  entry_id INT,
  topic_id INT
);
```

### entry_title_topics (Title Tags)
```sql
-- Populated by: sync_title_topics_from_tags
-- Used by: Topic title-based queries
CREATE TABLE entry_title_topics (
  entry_id INT,
  topic_id INT
);
```

---

## 📈 Performance Impact

### Tagger Duration:
- **Before**: ~10-20 minutes for 60 days
- **After**: ~15-30 minutes for 60 days (50% increase due to title extraction)

### Why It's Worth It:
- More complete data for topic dashboards
- Better PDF report accuracy
- Consistent with crawler behavior
- Catches title-based keywords that regular content extraction misses

---

## 🧪 Testing

### Manual Test:
```bash
# Test on a small dataset first
cd /var/www/morfeo
RAILS_ENV=production rake 'tagger[1]'  # Just today

# Check output for:
# - "TAGS: [...]"
# - "TITLE TAGS: [...]"
# - Both sync methods called
```

### Verify Sync:
```bash
# Check if both tables are populated
RAILS_ENV=production rails console

# Should have entries in both tables
> Entry.last.topics.count          # entry_topics
> Entry.last.title_topics.count    # entry_title_topics
```

---

## 🗓️ Schedule Impact

### Current Cron Jobs (No Changes):
```ruby
# config/schedule.rb

# Every 12 hours - recent entries
every 12.hours, at: ['8:00 am', '8:00 pm'] do
  rake 'tagger'  # Now extracts both tag types ✅
end

# Daily at 3 AM - deep historical
every 1.day, at: '3:00 am' do
  rake 'tagger[60]'  # Now extracts both tag types ✅
end
```

**No cron changes needed** - the tasks just do more work now! ✅

---

## 💡 Why Explicit Sync Calls?

### The Problem with Callbacks:
```ruby
# Entry model has callbacks:
after_save :sync_topics_from_tags, if: :saved_change_to_tag_list?
after_save :sync_title_topics_from_tags, if: :saved_change_to_title_tag_list?
```

**Issue**: `tag_list` and `title_tag_list` are **virtual attributes** from `acts_as_taggable_on`. The `saved_change_to_*?` condition might not always detect changes correctly.

### The Solution:
```ruby
# Explicitly call sync methods after save
entry.save!
entry.sync_topics_from_tags           # Force sync regular tags
entry.sync_title_topics_from_tags     # Force sync title tags
```

**Benefits**:
- ✅ Guaranteed sync regardless of callback detection
- ✅ Clear, explicit intent in code
- ✅ Easier to debug if something fails
- ✅ Consistent with background job patterns

---

## 🔄 Complete Sync Flow

```
Scheduled Cron Job (tagger)
        ↓
For each entry:
  1. Extract regular tags → tag_list
  2. Extract title tags → title_tag_list
  3. entry.save!
        ↓
  4. entry.sync_topics_from_tags
     → Updates entry_topics table
        ↓
  5. entry.sync_title_topics_from_tags
     → Updates entry_title_topics table
        ↓
Both tables now in sync ✅
```

---

## 📋 Deployment Checklist

- [x] Update `lib/tasks/tagger.rake` with title tag extraction
- [x] Add explicit sync calls for both tag types
- [x] Test locally with development data
- [x] Verify no linter errors
- [ ] Deploy to production
- [ ] Monitor first tagger run for errors
- [ ] Verify both `entry_topics` and `entry_title_topics` are populated
- [ ] Check Sidekiq for any failures
- [ ] Validate PDF reports show complete data

---

## 🚨 Rollback Plan

If issues occur:

```bash
# Stop cron
sudo systemctl stop cron

# Revert tagger.rake
cd /var/www/morfeo
git checkout HEAD~1 lib/tasks/tagger.rake

# Restart cron
sudo systemctl start cron
```

---

## 📚 Related Documentation

- [AUTO_SYNC_COMPLETE_FLOW.md](./AUTO_SYNC_COMPLETE_FLOW.md) - Complete sync system overview
- [DATABASE_SCHEMA.md](./DATABASE_SCHEMA.md) - entry_topics vs entry_title_topics tables
- [RAKE_TASKS_QUICK_REFERENCE.md](../RAKE_TASKS_QUICK_REFERENCE.md) - All available tasks

---

## ✅ Summary

| Feature | Before | After |
|---------|--------|-------|
| Regular Tags | ✅ Extracted | ✅ Extracted |
| Title Tags | ❌ Missing | ✅ Extracted |
| entry_topics Sync | ✅ Synced | ✅ Synced |
| entry_title_topics Sync | ❌ Not synced | ✅ Synced |
| Error Reporting | ⚠️ Silent failures | ✅ Clear messages |
| Crawler Consistency | ❌ Different pattern | ✅ Same pattern |

**Status**: ✅ Ready for production deployment


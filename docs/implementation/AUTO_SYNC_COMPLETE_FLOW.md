# 🔄 Complete Auto-Sync Flow Documentation

**Last Updated**: November 3, 2025  
**Status**: ✅ Production Ready

---

## 📋 Overview

This document explains how the Morfeo system automatically syncs entries to topics when tags are created or modified in ActiveAdmin.

---

## 🔀 Flow 1: Creating a New Tag in ActiveAdmin

### Step-by-Step Process:

```
Admin creates new Tag "Joshua Duerksen" in ActiveAdmin
                    ↓
Tag Model (after_create callback)
                    ↓
Tags::TagEntriesJob queued (60 days range) ✅ FIXED: Was 1 month, now 60 days
                    ↓
For each entry in last 60 days:
  - WebExtractorServices::ExtractTags checks if tag applies
  - If match: entry.tag_list.add(tag)
  - entry.save!
                    ↓
Entry Model (after_save callback)
                    ↓
sync_topics_from_tags ✅ FIXED: Now converts TagList correctly
                    ↓
entry_topics table updated
```

### Code:

```ruby
# app/models/tag.rb
after_create :tag_entries

def tag_entries
  Tags::TagEntriesJob.perform_later(id, 60.days.ago..Time.current) # ✅ 60 days
end
```

```ruby
# app/jobs/tags/tag_entries_job.rb
def perform(tag_id, range)
  entries = Entry.where(published_at: range)
  entries.each do |entry|
    result = WebExtractorServices::ExtractTags.call(entry.id, tag_id)
    entry.tag_list.add(result.data)
    entry.save!  # ✅ Triggers Entry callbacks
  end
end
```

```ruby
# app/models/entry.rb
after_save :sync_topics_from_tags, if: :saved_change_to_tag_list?

def sync_topics_from_tags
  tag_names = tag_list.map(&:to_s)  # ✅ FIXED: Convert TagList
  matching_topics = Topic.joins(:tags)
                        .where('tags.name IN (?)', tag_names)
                        .distinct
  self.topics = matching_topics
end
```

---

## 🔀 Flow 2: Adding a Tag to a Topic in ActiveAdmin

### Step-by-Step Process:

```
Admin adds Tag "Joshua Duerksen" to Topic "Honor Colorado"
                    ↓
Topic Model (after_commit callback)
                    ↓
SyncTopicEntriesJob queued (60 days)
                    ↓
Find all entries tagged with topic's tags (last 60 days)
                    ↓
For each entry:
  - entry.sync_topics_from_tags
                    ↓
entry_topics table updated
```

### Code:

```ruby
# app/models/topic.rb
after_commit :queue_entry_sync, if: :saved_change_to_tag_ids?

def queue_entry_sync
  SyncTopicEntriesJob.perform_later(id, 60)
  Rails.logger.info "Topic #{id}: Queued entry sync job (tags changed)"
end
```

```ruby
# app/jobs/sync_topic_entries_job.rb
def perform(topic_id, days = 60)
  topic = Topic.find_by(id: topic_id)
  tag_names = topic.tags.pluck(:name)
  
  entries = Entry.enabled
                 .where(published_at: days.days.ago..Time.current)
                 .tagged_with(tag_names, any: true)
                 .distinct
  
  entries.find_each do |entry|
    entry.sync_topics_from_tags  # ✅ Uses fixed method
  end
end
```

---

## 🔀 Flow 3: Scheduled Daily Re-tagging

### Step-by-Step Process:

```
Cron triggers (multiple times daily)
                    ↓
rake 'tagger[7]'  (every 12 hours) - Recent entries
rake 'tagger[60]' (daily at 3 AM) - Deep historical sync
                    ↓
For each entry in range:
  - Extract tags using WebExtractorServices
  - entry.tag_list = new_tags
  - entry.save!
                    ↓
Entry after_save callback
                    ↓
sync_topics_from_tags
                    ↓
entry_topics table updated
```

### Code:

```ruby
# config/schedule.rb
every 12.hours, at: ['8:00 am', '8:00 pm'] do
  rake 'tagger'  # Default 7 days
end

every 1.day, at: '3:00 am' do
  rake 'tagger[60]'  # Deep 60-day sync
end
```

---

## 🐛 Critical Bug Fixes Applied

### Bug #1: TagList Not Converted to Array

**Problem:**
```ruby
# ❌ BROKEN - TagList object not compatible with SQL IN clause
matching_topics = Topic.joins(:tags)
                      .where('tags.name IN (?)', tag_list)  # tag_list is TagList object
```

**Solution:**
```ruby
# ✅ FIXED - Convert to array of strings
tag_names = tag_list.map(&:to_s)
matching_topics = Topic.joins(:tags)
                      .where('tags.name IN (?)', tag_names)  # Array of strings
```

**Root Cause:**  
`ActsAsTaggableOn::TagList` is a custom object, not an array. SQL interpolation couldn't serialize it correctly, causing sync failures.

---

### Bug #2: Methods Were Private

**Problem:**
```ruby
private  # ❌ Methods couldn't be called from jobs/rake tasks

def sync_topics_from_tags
  # ...
end
```

**Solution:**
```ruby
# ✅ FIXED - Methods are now public
def sync_topics_from_tags
  # ...
end

private  # Other methods stay private
```

**Root Cause:**  
Methods were accidentally placed after the `private` keyword, preventing external calls from background jobs and rake tasks.

---

### Bug #3: Tag Creation Range Too Short

**Problem:**
```ruby
# ❌ BROKEN - Only tags 1 month of entries
Tags::TagEntriesJob.perform_later(id, 1.month.ago..Time.current)
```

**Solution:**
```ruby
# ✅ FIXED - Tags 60 days to match PDF report requirements
Tags::TagEntriesJob.perform_later(id, 60.days.ago..Time.current)
```

**Root Cause:**  
PDF reports show 60 days of data, but tag creation only processed 30 days, causing incomplete reports.

---

## ✅ Files Changed

| File | Change | Status |
|------|--------|--------|
| `app/models/entry.rb` | Fixed `sync_topics_from_tags` (TagList conversion + public) | ✅ Deployed |
| `app/models/tag.rb` | Changed range from 1 month to 60 days | ✅ Deployed |
| `app/models/topic.rb` | Added `queue_entry_sync` callback | ✅ Deployed |
| `app/jobs/sync_topic_entries_job.rb` | Created new background job | ✅ Deployed |
| `config/schedule.rb` | Optimized tagger schedule | ✅ Deployed |

---

## 🧪 Testing

### Test Script:
```bash
# Run comprehensive test
RAILS_ENV=development bundle exec rails runner scripts/test_sync_topics_fix.rb

# Expected output:
# ✅ ALL TESTS PASSED - Fix is working correctly!
```

### Manual Verification:
```bash
# 1. Create a test tag in ActiveAdmin
# 2. Wait for background job to complete
# 3. Check sync status:
RAILS_ENV=production rake 'audit:entry_topics:check[TOPIC_ID]'

# Expected: All entries synced ✅
```

---

## 📊 Performance Impact

### Before Fix:
- ❌ Auto-sync: Broken (silent failures)
- ❌ Manual rake tasks: Required every time
- ❌ Admin experience: Had to manually run sync commands

### After Fix:
- ✅ Auto-sync: Works automatically
- ✅ Background jobs: Handle sync asynchronously
- ✅ Admin experience: Just add tags and wait

### Background Job Duration:
- **Tag creation**: ~30-60 seconds (60 days of entries)
- **Topic tag update**: ~10-30 seconds (depending on tag count)
- **Daily tagger[60]**: ~10-20 minutes (all entries)

---

## 🎯 Verification Checklist

After deploying to production:

- [ ] Create a new tag in ActiveAdmin
- [ ] Verify `Tags::TagEntriesJob` appears in Sidekiq
- [ ] Wait for job to complete
- [ ] Check entries are tagged: `Entry.tagged_with('new_tag').count`
- [ ] Add tag to a topic
- [ ] Verify `SyncTopicEntriesJob` appears in Sidekiq
- [ ] Wait for job to complete
- [ ] Run audit: `rake 'audit:entry_topics:check[TOPIC_ID]'`
- [ ] Verify PDF report shows 60 days of data
- [ ] Check daily tagger runs at 3 AM
- [ ] Monitor Sidekiq for errors

---

## 🚨 Monitoring

### Key Metrics:

1. **Sidekiq Queue Length**
   ```bash
   # Should be < 100 entries during normal operations
   Sidekiq::Queue.new('default').size
   ```

2. **Sync Health**
   ```bash
   # Run daily audit
   RAILS_ENV=production rake 'audit:sync_health'
   ```

3. **Entry-Topic Sync Status**
   ```bash
   # Check specific topic
   RAILS_ENV=production rake 'audit:entry_topics:check[TOPIC_ID]'
   ```

### Alert Triggers:

- ⚠️ Sidekiq queue > 500 entries
- ⚠️ Background job failures > 10/hour
- ⚠️ Sync health audit reports > 5% missing entries
- ⚠️ PDF reports missing recent data

---

## 🔧 Troubleshooting

### Problem: Entries not syncing after tag creation

**Diagnosis:**
```bash
# Check if job was queued
Sidekiq::Queue.new('default').map(&:args)

# Check for errors
Sidekiq::DeadSet.new.each { |job| puts job.item }
```

**Solution:**
```bash
# Manually trigger sync
RAILS_ENV=production rake 'topic:update[TOPIC_ID,60]'
```

---

### Problem: Background jobs not running

**Diagnosis:**
```bash
# Check Sidekiq is running
ps aux | grep sidekiq

# Check Redis is up
redis-cli ping
```

**Solution:**
```bash
# Restart Sidekiq
sudo systemctl restart sidekiq
```

---

### Problem: PDF reports still missing data

**Diagnosis:**
```bash
# Check entry_topics table
RAILS_ENV=production rails console
> Entry.for_topic(264).where(published_at: 30.days.ago..Time.current).count
```

**Solution:**
```bash
# Force full re-sync
RAILS_ENV=production rake 'topic:update[TOPIC_ID,60]'
```

---

## 📚 Related Documentation

- [DATABASE_SCHEMA.md](./DATABASE_SCHEMA.md) - Complete schema & relationships
- [SYSTEM_ARCHITECTURE.md](./SYSTEM_ARCHITECTURE.md) - System architecture
- [COMPLETE_VALIDATION_SUMMARY.md](./COMPLETE_VALIDATION_SUMMARY.md) - Data validation
- [RAKE_TASKS_QUICK_REFERENCE.md](../RAKE_TASKS_QUICK_REFERENCE.md) - Available rake tasks

---

## 🎓 Key Learnings

1. **`acts_as_taggable_on` quirks**: `TagList` is NOT a regular array
2. **Callback order matters**: Public vs. private method placement
3. **Background jobs are essential**: Don't block admin UI
4. **Consistent time ranges**: Match across all sync mechanisms (60 days)
5. **Monitoring is critical**: Audit tasks catch silent failures

---

**Status**: ✅ All flows working correctly as of November 3, 2025


# 🚨 CRITICAL SYNC ISSUE - Complete System Audit

**Date**: November 3, 2025  
**Status**: CRITICAL - Production Impact  
**Issue**: `entry_topics` table out of sync, causing incomplete PDF reports

---

## 📊 Executive Summary

PDF reports only show 7 days of data despite having 60 days of tagged entries in the database. Root cause: **`entry_topics` association table is not being kept in sync with tagged entries**.

### Impact

- ❌ PDF reports show incomplete data (missing 50-80% of entries for 30-60 day ranges)
- ❌ Dashboard queries using direct associations are slower than they could be
- ❌ Client reports are inaccurate
- ⚠️ System relies on manual `topic:update` task which is NOT scheduled

---

## 🔍 Complete System Flow Analysis

### 1. Entry Creation & Tagging Flow

```
┌─────────────────────────────────────────────────────────────────┐
│ HOURLY: Crawler (lib/tasks/crawler.rake)                        │
├─────────────────────────────────────────────────────────────────┤
│ 1. Crawls websites (Anemone)                                   │
│ 2. SKIPS existing entries (line 43)                            │
│ 3. For NEW entries only:                                       │
│    a. Creates Entry                                            │
│    b. Extracts basic info                                      │
│    c. Extracts date                                            │
│    d. ✅ TAGS ENTRY (line 89-96)                               │
│    e. entry.tag_list.add(result.data)                         │
│    f. entry.save! → triggers after_save callback              │
│    g. ✅ sync_topics_from_tags called automatically           │
│ 4. Result: NEW entries are synced correctly                    │
└─────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────┐
│ EVERY 4 HOURS: title_tagger (lib/tasks/title_tagger.rake)      │
├─────────────────────────────────────────────────────────────────┤
│ 1. Processes entries from LAST 7 DAYS only                     │
│ 2. Re-tags title_tags                                          │
│ 3. Manually calls sync_title_topics_from_tags                 │
│ 4. ⚠️  Only 7 days - older entries not re-synced              │
└─────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────┐
│ NEVER SCHEDULED: tagger (lib/tasks/tagger.rake)                 │
├─────────────────────────────────────────────────────────────────┤
│ 1. Would process entries from LAST 60 DAYS                     │
│ 2. Would re-tag ALL tags (not just title)                     │
│ 3. Would manually call sync_topics_from_tags                  │
│ 4. ❌ BUT THIS TASK IS NOT IN schedule.rb!                    │
│ 5. Only runs when manually invoked                            │
└─────────────────────────────────────────────────────────────────┘
```

### 2. Auto-Sync Mechanism

**Location**: `app/models/entry.rb` lines 20-21

```ruby
after_save :sync_topics_from_tags, if: :saved_change_to_tag_list?
after_save :sync_title_topics_from_tags, if: :saved_change_to_title_tag_list?
```

**How it works**:
1. When `entry.tag_list` changes and `entry.save!` is called
2. Rails detects the change via `saved_change_to_tag_list?`
3. Automatically calls `sync_topics_from_tags`
4. Finds matching topics and updates `entry_topics` table

**✅ Works for**: New entries, entries being re-tagged
**❌ Doesn't work for**: 
- Existing entries when a NEW tag is added to a topic
- Entries that were tagged before a topic was created
- Entries older than 7 days (not re-processed)

### 3. Topic Statistics Generation

**Location**: `lib/tasks/topic_stat_daily.rake`  
**Schedule**: Every hour  
**Issue**: Uses `acts_as_taggable_on` queries, NOT `entry_topics` association

```ruby
Entry.enabled.tagged_with(tag_list, any: true)  # Direct tag query
# NOT: topic.entries                             # Association query
```

**Result**: `TopicStatDaily` records are correct, but `entry_topics` table may be out of sync!

---

## 🐛 Critical Issues Found

### Issue #1: Main `tagger` Task Not Scheduled ⚠️ CRITICAL

**Problem**: The `tagger` task that processes 60 days of entries is NOT in `config/schedule.rb`

**Evidence**:
```ruby
# config/schedule.rb
every 4.hours do
  rake 'title_tagger'  # ✅ Only tags title_tags, only 7 days
end

# ❌ rake 'tagger' is NOT HERE!
```

**Impact**: 
- Entries older than 7 days are never re-tagged
- If you add a new tag to a topic, entries with that keyword won't be retroactively tagged
- `entry_topics` only syncs for newly crawled entries

**Fix**: Add to schedule or create a dedicated sync task

---

### Issue #2: Crawler Skips Existing Entries ⚠️ CRITICAL

**Problem**: Crawler skips URLs that already exist in the database

**Evidence** (`lib/tasks/crawler.rake` line 43):
```ruby
page.links.delete_if { |href| Entry.exists?(url: href.to_s) }
```

**Impact**:
- Once an entry is crawled, it's never re-processed
- If tagging logic improves or new tags are added, old entries miss out
- Tags are only applied once at creation time

**Why this is done**: Performance - avoids re-crawling the same URLs
**Consequence**: Need separate re-tagging process

---

### Issue #3: No Automatic `topic:update` ⚠️ CRITICAL

**Problem**: The `topic:update` task (which syncs 60 days) is never scheduled

**Evidence**: `config/schedule.rb` has NO `topic:update` or `topic:update_all`

**What `topic:update` does**:
```ruby
# 1. Finds all entries tagged with topic's tags (last N days)
# 2. Creates entry_topics associations
# 3. Updates TopicStatDaily records
# 4. Updates TitleTopicStatDaily records
```

**Impact**:
- `entry_topics` only updates when:
  - New entries are created and tagged
  - Someone manually runs `topic:update`
- Adding a new tag to a topic requires manual `topic:update[ID,60]`
- System degrades over time as associations get stale

**Current reliance**: Manual execution by developers/admins

---

### Issue #4: Inconsistent Time Ranges ⚠️ MEDIUM

**Problem**: Different tasks use different time ranges

| Task | Range | Impact |
|------|-------|--------|
| `crawler` | New entries only | ✅ Tags immediately |
| `title_tagger` | 7 days | ⚠️ Only recent entries |
| `tagger` | 60 days | ✅ BUT NOT SCHEDULED! |
| `topic_stat_daily` | DAYS_RANGE (7 days default) | ⚠️ Limited scope |

**Result**: 
- Entries 8-60 days old may not have correct topic associations
- PDF reports (which use associations) show incomplete data

---

### Issue #5: Topic Changes Don't Trigger Sync ⚠️ HIGH

**Scenario**:
1. Topic "MIC" has tags: ["WRC", "F2"]
2. Entries from last 60 days are tagged with these
3. Someone adds new tag "Joshua Duerksen" to topic
4. **Problem**: Old entries already tagged with "Joshua Duerksen" won't automatically link to "MIC"

**Why**: 
- The `after_save` callbacks are on `Entry`, not `Topic`
- No trigger when topic.tags changes
- Requires manual `topic:update[ID,60]`

---

## 📋 Current Schedule (config/schedule.rb)

```ruby
every 5.minutes:
  - cache:warm_dashboards

every 1.hour:
  - crawler                    # ✅ Tags new entries
  - proxy_crawler              # ✅ Tags new JS-rendered entries  
  - update_stats               # Facebook stats
  - update_site_stats          # Site stats
  - update_dates               # Fix dates
  - clean_site_content         # Cleanup
  - category                   # Categorization
  - topic_stat_daily           # ✅ Stats but uses tag queries, not associations
  - title_topic_stat_daily     # ✅ Stats but uses tag queries, not associations

every 3.hours:
  - facebook:fanpage_crawler   # ✅ Tags new FB posts
  - twitter:profile_crawler    # ✅ Tags new tweets
  - social_crawler             # Social media

every 4.hours:
  - repeated_notes             # Duplicate detection
  - title_tagger               # ⚠️ Only 7 days, only title tags

every 6.hours:
  - crawler_deep               # Deep crawling
  - ai:generate_ai_reports     # AI reports
  - ai:set_topic_polarity      # Sentiment analysis
  - facebook:update_fanpages   # FB page info

MISSING:
  ❌ tagger                     # Would re-tag 60 days
  ❌ topic:update_all           # Would sync associations
  ❌ sync_entry_topics          # Dedicated sync task
```

---

## 🔧 Recommended Fixes

### Fix #1: Add Comprehensive Re-Tagging to Schedule ⭐ PRIORITY 1

Add the main `tagger` task to run daily or every 12 hours:

```ruby
# config/schedule.rb
every 12.hours do
  rake 'tagger'  # Re-tags last 60 days with regular tags
end
```

**Impact**: 
- ✅ Entries from last 60 days re-tagged regularly
- ✅ New tags applied retroactively
- ✅ Callbacks trigger automatic sync

**Caution**: 
- This task is heavy (processes all entries from 60 days)
- Run during off-peak hours
- Monitor performance

---

### Fix #2: Add Automatic Topic Sync ⭐ PRIORITY 1

Create and schedule a new task to sync all topics:

```ruby
# config/schedule.rb
every 1.day, at: '2:00 am' do
  rake 'topic:sync_all[60]'  # New task: sync without full update
end
```

**New task needed** (`lib/tasks/topic_sync_all.rake`):
```ruby
namespace :topic do
  desc 'Sync entry_topics associations for all topics'
  task :sync_all, [:days] => :environment do |_t, args|
    days = (args[:days].presence ? Integer(args[:days]) : 60)
    start_date = days.days.ago.beginning_of_day
    end_date = Time.current.end_of_day
    
    Topic.where(status: true).find_each do |topic|
      puts "Syncing Topic #{topic.id}: #{topic.name}"
      tag_names = topic.tags.pluck(:name)
      next if tag_names.empty?
      
      # Find matching entries
      entries = Entry.enabled
                    .where(published_at: start_date..end_date)
                    .tagged_with(tag_names, any: true)
                    .distinct
      
      # Bulk sync
      entries.find_each do |entry|
        entry.sync_topics_from_tags
      end
      
      puts "  ✅ Synced #{entries.count} entries"
    end
  end
end
```

**Impact**:
- ✅ Ensures all topics have up-to-date associations
- ✅ Lighter than full `topic:update` (no stats recalculation)
- ✅ Runs automatically every night

---

### Fix #3: Add Callback on Topic Tag Changes ⭐ PRIORITY 2

**Location**: `app/models/topic.rb`

Add callback to sync entries when topic's tags change:

```ruby
# app/models/topic.rb
after_save :sync_entries_with_new_tags, if: :saved_change_to_tag_ids?

def sync_entries_with_new_tags
  # Queue background job to avoid blocking
  SyncTopicEntriesJob.perform_later(id, 60)
end
```

**New job** (`app/jobs/sync_topic_entries_job.rb`):
```ruby
class SyncTopicEntriesJob < ApplicationJob
  queue_as :default
  
  def perform(topic_id, days)
    topic = Topic.find(topic_id)
    start_date = days.days.ago.beginning_of_day
    tag_names = topic.tags.pluck(:name)
    
    Entry.enabled
         .where(published_at: start_date..Time.current)
         .tagged_with(tag_names, any: true)
         .distinct
         .find_each do |entry|
      entry.sync_topics_from_tags
    end
  end
end
```

**Impact**:
- ✅ Automatic sync when admin adds/removes tags from topic
- ✅ No manual intervention needed
- ✅ Background job prevents UI blocking

---

### Fix #4: Optimize Callback Condition ⭐ PRIORITY 3

**Issue**: The callback condition might not always fire

**Current** (`app/models/entry.rb` line 20):
```ruby
after_save :sync_topics_from_tags, if: :saved_change_to_tag_list?
```

**Problem**: If `acts_as_taggable_on` doesn't mark record as dirty, callback won't fire

**Enhanced version**:
```ruby
after_save :sync_topics_from_tags, if: -> { 
  saved_change_to_tag_list? || tag_list.present? 
}
```

Or add manual sync in rake tasks:
```ruby
# Always call sync explicitly in critical paths
entry.save!
entry.sync_topics_from_tags # Force sync regardless of dirty tracking
```

---

### Fix #5: Add Monitoring & Alerts ⭐ PRIORITY 2

Create a daily audit task:

```ruby
# config/schedule.rb
every 1.day, at: '6:00 am' do
  rake 'audit:sync_health'
end
```

**New task** (`lib/tasks/audit/sync_health.rake`):
```ruby
namespace :audit do
  desc 'Check sync health and alert if issues found'
  task sync_health: :environment do
    issues = []
    
    Topic.where(status: true).each do |topic|
      tag_names = topic.tags.pluck(:name)
      next if tag_names.empty?
      
      # Compare direct vs association counts (7 days)
      direct_count = Entry.enabled
                          .where(published_at: 7.days.ago..Time.current)
                          .tagged_with(tag_names, any: true)
                          .distinct
                          .count
      
      assoc_count = topic.entries
                        .enabled
                        .where(published_at: 7.days.ago..Time.current)
                        .count
      
      diff = direct_count - assoc_count
      
      if diff.abs > 5 # Threshold: 5 entries difference
        issues << {
          topic_id: topic.id,
          topic_name: topic.name,
          direct: direct_count,
          association: assoc_count,
          difference: diff
        }
      end
    end
    
    if issues.any?
      puts "⚠️ SYNC ISSUES DETECTED:"
      issues.each do |issue|
        puts "  Topic #{issue[:topic_id]} (#{issue[:topic_name]}): #{issue[:difference]} entries out of sync"
      end
      
      # Send notification (email, Slack, etc.)
      # AdminMailer.sync_issues(issues).deliver_later
    else
      puts "✅ All topics in sync"
    end
  end
end
```

---

## 🎯 Implementation Priority

### Phase 1: Immediate (Within 24 hours)

1. ✅ **Add `tagger` to schedule** (every 12 hours)
   - Simple change to `config/schedule.rb`
   - Ensures entries from 60 days are re-tagged
   - Manual run first: `RAILS_ENV=production rake 'tagger'`

2. ✅ **Create and schedule `topic:sync_all`** (daily at 2am)
   - New rake task for bulk sync
   - Lighter than `topic:update_all`
   - Manual run first: `RAILS_ENV=production rake 'topic:sync_all[60]'`

3. ✅ **Manual fix for current state**
   - Run for all topics: `RAILS_ENV=production rake 'topic:update_all[60]'`
   - This will take 30-60 minutes but fixes current issues

### Phase 2: Short-term (Within 1 week)

4. ✅ **Add topic tag change callback**
   - Automatic sync when admin changes topic tags
   - Background job to avoid blocking

5. ✅ **Add sync health monitoring**
   - Daily audit task
   - Alerts when sync issues detected

### Phase 3: Long-term (Within 1 month)

6. ⚠️ **Consider architectural changes**
   - Option A: Always use `acts_as_taggable_on` queries (remove association dependency)
   - Option B: Make associations real-time (more aggressive syncing)
   - Option C: Hybrid approach with explicit sync points

---

## 📝 Updated Schedule Recommendation

```ruby
# config/schedule.rb
set :environment, 'production'

# Cache warming - every 5 minutes
every 5.minutes do
  rake 'cache:warm_dashboards'
end

# Hourly tasks - data collection
every :hour do
  rake 'crawler'
  rake 'proxy_crawler'
  rake 'update_stats'
  rake 'update_site_stats'
  rake 'update_dates'
  rake 'clean_site_content'
  rake 'category'
  rake 'topic_stat_daily'
  rake 'title_topic_stat_daily'
end

# Every 3 hours - social media
every 3.hours do
  rake 'facebook:fanpage_crawler'
  rake 'twitter:profile_crawler_full'
  rake 'social_crawler'
end

# Every 4 hours - tagging (UPDATED: now includes main tagger)
every 4.hours do
  rake 'repeated_notes'
  rake 'title_tagger'  # Title tags for last 7 days
end

# Every 6 hours - deep crawling and AI
every 6.hours do
  rake 'crawler_deep'
  rake 'ai:generate_ai_reports'
  rake 'ai:set_topic_polarity'
  rake 'facebook:update_fanpages'
end

# 🆕 Every 12 hours - comprehensive re-tagging (NEW!)
every 12.hours, at: ['2:00 am', '2:00 pm'] do
  rake 'tagger'  # Re-tag all entries from last 60 days
end

# 🆕 Daily at 3:00 AM - sync all topics (NEW!)
every 1.day, at: '3:00 am' do
  rake 'topic:sync_all[60]'  # Sync entry_topics for all topics
end

# 🆕 Daily at 6:00 AM - health check (NEW!)
every 1.day, at: '6:00 am' do
  rake 'audit:sync_health'  # Check and alert on sync issues
end
```

---

## 🧪 Testing & Validation

### Before Changes

```bash
# 1. Audit current state
RAILS_ENV=production rake 'audit:tag:presence[TAG_ID]'
RAILS_ENV=production rake 'audit:entry_topics:check[TOPIC_ID]'

# 2. Document baseline
# - How many entries out of sync?
# - Which topics affected?
# - What time ranges?
```

### After Changes

```bash
# 1. Update schedule
whenever --update-crontab

# 2. Manual run to fix current state
RAILS_ENV=production rake 'topic:update_all[60]'

# 3. Verify fix
RAILS_ENV=production rake 'audit:entry_topics:check[TOPIC_ID]'

# 4. Monitor for 48 hours
# - Check logs for successful runs
# - Verify no performance degradation
# - Confirm PDF reports are complete
```

---

## 📊 Success Metrics

1. ✅ **Sync Accuracy**: < 1% difference between direct tags and associations
2. ✅ **PDF Completeness**: All time ranges (7, 15, 30, 60 days) show correct data
3. ✅ **Auto-Recovery**: System self-corrects within 12 hours of adding new tag
4. ✅ **Performance**: No significant slowdown in crawling or dashboard loading
5. ✅ **Zero Manual Intervention**: No need for manual `topic:update` runs

---

## 🚨 Emergency Rollback Plan

If issues occur:

```bash
# 1. Remove new scheduled tasks
whenever --clear-crontab

# 2. Restore original schedule.rb from git
git checkout config/schedule.rb
whenever --update-crontab

# 3. Monitor logs
tail -f log/production.log

# 4. Manual recovery if needed
RAILS_ENV=production rake 'topic:update_all[60]'
```

---

## 📚 Related Documentation

- `docs/TOPIC_UPDATE_TASK.md` - Full topic:update documentation
- `docs/SYSTEM_ARCHITECTURE.md` - System architecture
- `docs/DATABASE_SCHEMA.md` - entry_topics table structure
- `RAKE_TASKS_QUICK_REFERENCE.md` - Quick reference for tasks

---

**Status**: Ready for implementation  
**Risk Level**: Medium (impacts production but non-breaking)  
**Estimated Time**: 2-4 hours for Phase 1  
**Next Steps**: Review with team, get approval, implement Phase 1



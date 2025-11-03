# Topic Update Rake Task

## 📋 Overview

The `topic:update` rake task provides a comprehensive solution to update **all data** for a specific topic, including:

- ✅ **Cache clearing** (all dashboard and service caches)
- ✅ **Tagging** (digital entries, Facebook posts, Twitter posts)
- ✅ **Relations** (entry_topics and entry_title_topics synchronization)
- ✅ **Statistics** (TopicStatDaily and TitleTopicStatDaily)
- ✅ **Cache warming** (pre-warm all dashboards)

---

## 🚀 Usage

### Update a Single Topic

```bash
# Update topic #1 (default: last 7 days)
rake 'topic:update[1]'

# Update topic #1 (last 15 days) - for 15-day PDF reports
rake 'topic:update[1,15]'

# Update topic #1 (last 30 days) - for 30-day PDF reports
rake 'topic:update[1,30]'

# Update topic #1 (last 60 days) - for 60-day PDF reports (RECOMMENDED)
rake 'topic:update[1,60]'
```

> **💡 Tip**: For PDF reports with date range selectors (7, 15, 30, 60 days), it's recommended to update at least 60 days of data to ensure all report variants have fresh data.
> 
> **Note**: Single quotes are required for zsh compatibility. If using bash, quotes are optional.

### Update Multiple Topics

```bash
# Update topics 1, 2, and 3 (default: last 7 days)
rake 'topic:update_multiple[1,2,3]'

# Update topics 1, 2, and 3 (last 30 days)
rake 'topic:update_multiple[1,2,3,30]'

# Update topics 1, 2, and 3 (last 60 days) - RECOMMENDED for PDF reports
rake 'topic:update_multiple[1,2,3,60]'
```

### Update All Active Topics

```bash
# Update all active topics (default: last 7 days)
rake 'topic:update_all'

# Update all active topics (last 30 days)
rake 'topic:update_all[30]'

# Update all active topics (last 60 days) - RECOMMENDED for PDF reports
rake 'topic:update_all[60]'
```

> **⚠️ Important**: Since PDF reports now support 7, 15, 30, and 60-day ranges, it's recommended to maintain at least 60 days of updated data for all active topics.
> 
> **Note**: Single quotes are required for zsh compatibility. If using bash, quotes are optional.

---

## 📊 What Gets Updated

### 1. **Cache Clearing** 🧹

Clears **ALL** cached data for the topic (both Redis service caches and action caches):

**Redis Service Caches** (dashboard data):
```ruby
- topic_{id}_*                    # Topic model caches
- digital_dashboard_{id}_*        # Digital dashboard service cache
- facebook_dashboard_{id}_*       # Facebook dashboard service cache
- twitter_dashboard_{id}_*        # Twitter dashboard service cache
- general_dashboard_{id}_*        # General dashboard service cache
```

**Action Caches** (rendered views):
```ruby
- views/topic/show/topic_id={id}*              # Digital dashboard HTML
- views/topic/pdf/topic_id={id}*               # Digital PDF
- views/general_dashboard/show/topic_id={id}*  # General dashboard HTML
- views/general_dashboard/pdf/topic_id={id}*   # General PDF
- views/facebook_topic/show/topic_id={id}*     # Facebook dashboard HTML
- views/facebook_topic/pdf/topic_id={id}*      # Facebook PDF
- views/twitter_topic/show/topic_id={id}*      # Twitter dashboard HTML
- views/twitter_topic/pdf/topic_id={id}*       # Twitter PDF
```

> **Note**: Clears caches for all date ranges (7, 15, 30, 60 days) and all users who have accessed this topic.

### 2. **Digital Entry Tagging** 📰

- Retags all digital entries in the date range
- Uses `WebExtractorServices::ExtractTags` to analyze content
- Automatically syncs `entry_topics` and `entry_title_topics` relations
- Shows progress every 50 entries

### 3. **Facebook Entry Tagging** 📘

- Retags all Facebook posts in the date range
- Uses `WebExtractorServices::ExtractFacebookEntryTags`
- Inherits tags from linked entries when available
- Removes "Facebook" and "WhatsApp" tags (noise)
- Shows progress every 50 entries

### 4. **Twitter Post Tagging** 🐦

- Retags all Twitter posts in the date range
- Uses `TwitterServices::ExtractTags`
- Inherits tags from linked entries when available
- Removes "Twitter" tag (noise)
- Shows progress every 50 entries

### 5. **Entry-Topic Relations Sync** 🔗

- Syncs `entry_topics` table (regular tags)
- Syncs `entry_title_topics` table (title tags)
- Ensures all entries with matching tags are associated with the topic
- Critical for `USE_DIRECT_ENTRY_TOPICS=true` mode

### 6. **Daily Statistics Update** 📈

Updates for each day in the date range:

**TopicStatDaily**:
- `entry_count` - Number of entries
- `total_count` - Total interactions
- `average` - Average interactions per entry
- `neutral_quantity`, `positive_quantity`, `negative_quantity`
- `neutral_interaction`, `positive_interaction`, `negative_interaction`

**TitleTopicStatDaily**:
- `entry_quantity` - Entries with topic in title
- `entry_interaction` - Total interactions for title matches

### 7. **Cache Warming** 🔥

Pre-warms all dashboard caches:
- Digital dashboard (`DigitalDashboardServices::AggregatorService`)
- Facebook dashboard (`FacebookDashboardServices::AggregatorService`)
- Twitter dashboard (`TwitterDashboardServices::AggregatorService`)
- General dashboard (`GeneralDashboardServices::AggregatorService`)

---

## 📋 Example Output

```
================================================================================
🚀 UPDATING TOPIC: Santiago Peña (ID: 1)
================================================================================
📅 Date Range: Last 30 days (2025-10-04 - 2025-11-03)
🏷️  Topic Tags: Santiago Peña, Presidente, Paraguay
================================================================================

📍 STEP 1/6: Clearing topic caches...
--------------------------------------------------------------------------------
   ✅ Cleared: topic_1_*
   ✅ Cleared: digital_dashboard_1_*
   ✅ Cleared: facebook_dashboard_1_*
   ✅ Cleared: twitter_dashboard_1_*
   ✅ Cleared: general_dashboard_1_*
✅ Step 1 Complete: All topic caches cleared

📍 STEP 2/6: Retagging digital entries...
--------------------------------------------------------------------------------
   📊 Found 345 entries to process
   ⏳ Progress: 50/345 entries...
   ⏳ Progress: 100/345 entries...
   ⏳ Progress: 150/345 entries...
   ⏳ Progress: 200/345 entries...
   ⏳ Progress: 250/345 entries...
   ⏳ Progress: 300/345 entries...
   ✅ Tagged: 342 entries
   ⚠️  Failed: 3 entries
✅ Step 2 Complete: Digital entries retagged

📍 STEP 3/6: Retagging Facebook entries...
--------------------------------------------------------------------------------
   📊 Found 89 Facebook entries to process
   ⏳ Progress: 50/89 Facebook entries...
   ✅ Tagged: 87 entries (12 inherited from linked entries)
   ⚠️  Failed: 2 entries
✅ Step 3 Complete: Facebook entries retagged

📍 STEP 4/6: Retagging Twitter posts...
--------------------------------------------------------------------------------
   📊 Found 156 Twitter posts to process
   ⏳ Progress: 50/156 Twitter posts...
   ⏳ Progress: 100/156 Twitter posts...
   ⏳ Progress: 150/156 Twitter posts...
   ✅ Tagged: 154 posts (8 inherited from linked entries)
   ⚠️  Failed: 2 posts
✅ Step 4 Complete: Twitter posts retagged

📍 STEP 5/6: Syncing entry-topic relations...
--------------------------------------------------------------------------------
   ✅ Synced 342 entries with topics (via entry_topics)
   ✅ Synced 298 entries with topics (via entry_title_topics)
✅ Step 5 Complete: Entry-topic relations synced

📍 STEP 6/6: Updating daily statistics...
--------------------------------------------------------------------------------
   ✅ Updated statistics for 30 days
✅ Step 6 Complete: Daily statistics updated

================================================================================
🎉 TOPIC UPDATE COMPLETE!
================================================================================
📊 Summary:
   Topic: Santiago Peña (ID: 1)
   Date Range: 30 days (2025-10-04 - 2025-11-03)
   Duration: 187.45 seconds (3.12 minutes)

   📰 Digital Entries:
      • Total: 345
      • Tagged: 342
      • Failed: 3

   📘 Facebook Entries:
      • Total: 89
      • Tagged: 87
      • Inherited: 12
      • Failed: 2

   🐦 Twitter Posts:
      • Total: 156
      • Tagged: 154
      • Inherited: 8
      • Failed: 2

   🔗 Relations:
      • Entry-Topics synced: 342
      • Title-Topics synced: 298

   📈 Statistics:
      • Days updated: 30

   🧹 Caches:
      • All topic caches cleared
================================================================================

🔥 Warming caches for topic...
   ✅ Digital dashboard cache warmed
   ✅ Facebook dashboard cache warmed
   ✅ Twitter dashboard cache warmed
   ✅ General dashboard cache warmed

================================================================================
✅ All done! Topic 'Santiago Peña' is fully updated and ready to use.
================================================================================
```

---

## ⚡ Performance Considerations

### Execution Time Estimates

| Topics | Days | Approx. Time |
|--------|------|--------------|
| 1 topic | 7 days | 30-90 seconds |
| 1 topic | 30 days | 2-5 minutes |
| 1 topic | 60 days | 4-10 minutes |
| 5 topics | 7 days | 3-8 minutes |
| 5 topics | 30 days | 10-25 minutes |
| All topics (20) | 7 days | 10-30 minutes |

**Factors affecting speed**:
- Number of entries to process
- API rate limits (tagging services)
- Database performance
- Redis performance

### Memory Usage

- Uses `.find_each` for batch processing (500 records at a time)
- Memory efficient even for large datasets
- Suitable for background jobs or cron

---

## 🔧 Use Cases

### 1. **After Adding New Tags to a Topic**

When you add new tags to a topic, run this to re-associate all matching entries:

```bash
rake 'topic:update[1,30]'
```

### 2. **After Bulk Data Import**

When importing historical data, run this to tag and associate everything:

```bash
rake 'topic:update[1,60]'  # Full 60-day range for complete PDF report coverage
```

### 3. **Dashboard Data Issues**

When dashboard shows incorrect counts or missing entries:

```bash
# Clear caches, retag, resync, and warm caches
rake 'topic:update[1]'
```

### 4. **Daily Maintenance**

For critical topics, run daily updates to ensure data freshness:

```bash
# Add to cron (runs every day at 2 AM)
# Note: Use 60 days to support all PDF report ranges
0 2 * * * cd /path/to/morfeo && RAILS_ENV=production rake 'topic:update[1,60]'
```

### 5. **After System Upgrades**

After upgrading the tagging algorithm or changing topic configuration:

```bash
# Update all topics with latest logic (60 days for full PDF coverage)
rake 'topic:update_all[60]'
```

### 6. **Before Generating PDF Reports**

Ensure data is fresh for all PDF report ranges (7, 15, 30, 60 days):

```bash
# Update specific topic with full 60-day range
rake 'topic:update[TOPIC_ID,60]'

# Or update all topics
rake 'topic:update_all[60]'
```

---

## 🛡️ Safety Features

### Error Handling

- ✅ Validates topic ID exists
- ✅ Graceful error handling (doesn't stop on individual entry failures)
- ✅ Detailed error messages
- ✅ Summary report with success/failure counts

### Non-Destructive

- ✅ Only updates data, doesn't delete
- ✅ Safe to run multiple times (idempotent)
- ✅ Can be interrupted and re-run

### Progress Indicators

- ✅ Shows step-by-step progress
- ✅ Updates every 50 entries
- ✅ Final summary report

---

## 🔗 Related Tasks

| Task | Purpose |
|------|---------|
| `rake tagger` | Retag entries (last 7 days) |
| `rake facebook:entry_tagger` | Retag Facebook entries |
| `rake twitter:post_tagger` | Retag Twitter posts |
| `rake entries:sync_topics` | Sync entry-topic relations |
| `rake topic_stat_daily` | Update daily statistics |
| `rake cache:warm` | Warm all caches |
| `rake cache:clear` | Clear all caches |

---

## 📝 Notes

### When to Use This Task

✅ **Use when**:
- Dashboard shows incorrect data
- After adding/removing tags from a topic
- After bulk data import
- After system upgrades
- For regular maintenance

❌ **Don't use when**:
- Just need to clear caches → use `rake cache:clear`
- Only need to warm caches → use `rake cache:warm`
- Real-time updates → this is for batch processing

### Environment Variables

Make sure these are set correctly:

```bash
# Use direct entry_topics association (recommended)
USE_DIRECT_ENTRY_TOPICS=true

# Days range for default operations
DAYS_RANGE=7
```

### Cron Schedule Example

Add to `config/schedule.rb`:

```ruby
# Update critical topics daily
every 1.day, at: '2:00 AM' do
  rake "topic:update[1,7]"
  rake "topic:update[2,7]"
  rake "topic:update[3,7]"
end

# Update all topics weekly
every :sunday, at: '3:00 AM' do
  rake "topic:update_all[30]"
end
```

---

## 🆘 Troubleshooting

### "Topic not found" Error

```bash
❌ Error: Topic #999 not found
```

**Solution**: Verify the topic ID exists:

```ruby
Topic.find(999)  # Should not raise error
```

### "No tags" Warning

```bash
⚠️  WARNING: Topic has no tags. Some operations will be skipped.
```

**Solution**: Add tags to the topic in ActiveAdmin

### High Failure Rate

```bash
⚠️  Failed: 150 entries
```

**Solution**: Check Rails logs for specific errors:

```bash
tail -f log/production.log
```

Common causes:
- API rate limits
- Network issues
- Invalid data

---

## ✅ Validation

After running the task, verify:

1. **Dashboard loads correctly**
   - Visit topic dashboard
   - Check entry counts
   - Verify graphs show data

2. **Entry-topic associations**
   ```ruby
   topic = Topic.find(1)
   topic.entries.count  # Should match tagged entries
   ```

3. **Daily statistics**
   ```ruby
   topic = Topic.find(1)
   topic.topic_stat_dailies.where(topic_date: 7.days.ago..Date.current).count
   # Should be 8 (today + 7 days ago)
   ```

4. **Cache exists**
   ```ruby
   Rails.cache.exist?("digital_dashboard_1_7_#{Date.current}")  # Should be true
   ```

---

**Last Updated**: November 3, 2025
**Maintainer**: Morfeo Development Team


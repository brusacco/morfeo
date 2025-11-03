# Morfeo - Rake Tasks Quick Reference

## 🎯 Most Common Tasks

### Topic Management

```bash
# Update all data for a topic (recommended when having issues)
rake 'topic:update[TOPIC_ID]'                  # Last 7 days (default)
rake 'topic:update[TOPIC_ID,15]'               # Last 15 days
rake 'topic:update[TOPIC_ID,30]'               # Last 30 days
rake 'topic:update[TOPIC_ID,60]'               # Last 60 days (RECOMMENDED for PDF reports)

# Update multiple topics
rake 'topic:update_multiple[1,2,3]'            # Topics 1, 2, 3 (default 7 days)
rake 'topic:update_multiple[1,2,3,30]'         # Last 30 days
rake 'topic:update_multiple[1,2,3,60]'         # Last 60 days (RECOMMENDED)

# Update all active topics
rake 'topic:update_all'                        # All topics, 7 days
rake 'topic:update_all[30]'                    # All topics, 30 days
rake 'topic:update_all[60]'                    # All topics, 60 days (RECOMMENDED)
```

> **💡 Best Practice**: For production systems with PDF reports, update at least 60 days of data to support all report ranges (7, 15, 30, 60 days).
>
> **Note**: Single quotes are required for zsh compatibility. If using bash, quotes are optional.

### Cache Management

```bash
# Clear all caches
rake cache:clear

# Warm specific caches
rake cache:warm                                # Warm everything
rake cache:warm_dashboards                     # Dashboards only (faster)
rake 'cache:warm_topic[TOPIC_ID]'              # One topic only

# Clear and refresh
rake cache:refresh                             # Clear + warm
```

### Tagging

```bash
# Digital entries
rake tagger                                    # Tag entries (last 7 days)
rake retagger                                  # Retag entries without tags

# Facebook
rake facebook:entry_tagger                     # Tag Facebook posts

# Twitter
rake twitter:post_tagger                       # Tag Twitter posts
```

### Data Synchronization

```bash
# Sync entry-topic relations
rake entries:sync_topics                       # All entries
rake 'entries:sync_entry[ENTRY_ID]'            # Single entry
rake 'entries:check_topic_sync[TOPIC_ID]'      # Check sync status

# Update statistics
rake topic_stat_daily                          # Update daily stats
rake title_topic_stat_daily                    # Update title stats
```

### Data Collection (Crawlers)

```bash
# Digital media
rake crawler                                   # Crawl all sites
rake 'crawler_site[SITE_ID]'                   # Crawl single site

# Facebook
rake facebook:fanpage_crawler                  # Update Facebook pages
rake facebook:entries                          # Fetch Facebook posts

# Twitter
rake twitter:profile_crawler                   # Update Twitter profiles
rake twitter:profile_crawler_full              # Full Twitter update
```

---

## 📊 Maintenance Schedule (Production)

### Daily (Automated via Cron)

```bash
# Every 10 minutes - Warm caches
rake cache:warm_dashboards

# Every hour - Quick crawler
rake crawler_fast

# Daily at 2 AM - Full crawlers
rake crawler
rake facebook:entries
rake twitter:profile_crawler_full

# Daily at 3 AM - Update tags and stats
rake tagger
rake facebook:entry_tagger
rake twitter:post_tagger
rake entries:sync_topics
rake topic_stat_daily
```

### Weekly

```bash
# Sunday at 3 AM - Full topic update (60 days for PDF reports)
rake topic:update_all[60]
```

### As Needed

```bash
# Before major presentations or when data looks stale
rake topic:update_all[60]
```

---

## 🆘 Troubleshooting Commands

### Dashboard Not Loading / Showing Wrong Data

```bash
# Full topic refresh (recommended - 60 days for PDF reports)
rake 'topic:update[TOPIC_ID,60]'

# Or step by step:
rake cache:clear                               # 1. Clear caches
rake tagger                                    # 2. Retag entries
rake facebook:entry_tagger                     # 3. Tag Facebook
rake twitter:post_tagger                       # 4. Tag Twitter
rake entries:sync_topics                       # 5. Sync relations
rake topic_stat_daily                          # 6. Update stats
rake 'cache:warm_topic[TOPIC_ID]'              # 7. Warm cache
```

### No Entries Showing for Topic

```bash
# Check if entries are tagged
rake 'entries:check_topic_sync[TOPIC_ID]'

# If mismatch found, sync them
rake entries:sync_topics

# Then verify
rake 'entries:check_topic_sync[TOPIC_ID]'
```

### Statistics Not Updating

```bash
# Regenerate stats for all topics
rake topic_stat_daily

# Check specific date
rails console
> TopicStatDaily.where(topic_id: 1, topic_date: Date.current)
```

### Slow Dashboard Performance

```bash
# Warm caches
rake cache:warm_dashboards

# Or warm specific topic
rake 'cache:warm_topic[TOPIC_ID]'
```

---

## 🔍 Diagnostic Commands

### Check Cache Status

```ruby
# In Rails console
Rails.cache.exist?("digital_dashboard_1_7_#{Date.current}")
Rails.cache.read("digital_dashboard_1_7_#{Date.current}")
```

### Check Entry Counts

```ruby
# In Rails console
topic = Topic.find(1)

# Via tags (old method)
Entry.tagged_with(topic.tags.pluck(:name), any: true).count

# Via relations (new method)
topic.entries.count

# Should be the same!
```

### Check Topic Configuration

```ruby
# In Rails console
topic = Topic.find(1)
topic.tags.pluck(:name)                        # Check tags
topic.entries.count                            # Entry count
topic.topics.count                             # Associated entries
```

---

## 🎓 Understanding the Update Process

When you run `rake topic:update[ID]`, it performs these steps:

1. **Clear Caches** 🧹

   - Removes all cached data for the topic
   - Ensures fresh data on next load

2. **Retag Digital Entries** 📰

   - Analyzes content with AI/ML
   - Assigns relevant tags
   - Syncs topics automatically

3. **Retag Facebook Posts** 📘

   - Extracts tags from post content
   - Inherits from linked entries
   - Removes noise tags (Facebook, WhatsApp)

4. **Retag Twitter Posts** 🐦

   - Extracts tags from tweet content
   - Inherits from linked entries
   - Removes noise tags (Twitter)

5. **Sync Relations** 🔗

   - Updates `entry_topics` table
   - Updates `entry_title_topics` table
   - Critical for fast dashboard queries

6. **Update Statistics** 📈

   - Recalculates `TopicStatDaily`
   - Recalculates `TitleTopicStatDaily`
   - Used for charts and trends

7. **Warm Caches** 🔥
   - Pre-loads dashboard data
   - Ensures instant page loads
   - All 4 dashboards cached

---

## ⚡ Quick Decision Tree

**Having issues with a topic?**

```
Is it one specific topic?
  ├─ Yes → rake 'topic:update[ID]'
  └─ No  → Are all topics affected?
          ├─ Yes → rake cache:clear && rake cache:warm_dashboards
          └─ No  → rake 'topic:update_multiple[1,2,3]'

Dashboard loads but shows old data?
  ├─ Just cache issue → rake cache:clear
  └─ Data + cache     → rake 'topic:update[ID,60]'

Entries not appearing?
  ├─ Check sync → rake 'entries:check_topic_sync[ID]'
  ├─ If mismatch → rake entries:sync_topics
  └─ Still wrong → rake 'topic:update[ID,60]'

PDF reports missing data for 30/60 day ranges?
  └─ rake 'topic:update[ID,60]'  # Update full 60-day range

After system upgrade?
  └─ rake 'topic:update_all[60]'

After adding new tags to topic?
  └─ rake 'topic:update[ID,60]'
```

---

## 📝 Environment Variables

Make sure these are set in `.env`:

```bash
# Use direct entry_topics (required for fast queries)
USE_DIRECT_ENTRY_TOPICS=true

# Default days range
DAYS_RANGE=7

# Redis for caching
REDIS_URL=redis://localhost:6379/0
```

---

## 🔗 Full Documentation

For complete details, see:

- `/docs/TOPIC_UPDATE_TASK.md` - Full topic:update documentation
- `/docs/CACHING_STRATEGY.md` - Cache architecture
- `/docs/SYSTEM_ARCHITECTURE.md` - Overall system design

---

**Quick Help**: `rake -T topic` or `rake -T cache` to list all available tasks

**Last Updated**: November 3, 2025

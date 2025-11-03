# 📊 Topic Stat Daily - 60 Days Support

**Date**: November 3, 2025  
**Issue**: PDF temporal charts only showed 7 days even when requesting 60-day reports  
**Status**: ✅ Fixed

---

## 🎯 Problem

When generating a 60-day PDF report:
- ✅ Total counts were correct (317 entries)
- ❌ **Temporal charts** only showed 7 days of data

### Root Cause:

The PDF temporal charts use the `topic_stat_dailies` table (pre-aggregated daily statistics), not raw entries:

```ruby
# app/services/digital_dashboard_services/pdf_service.rb
stats = @topic.topic_stat_dailies
              .where(topic_date: @start_date.to_date..@end_date.to_date)
```

The `topic_stat_daily` rake task only updated the last **7 days** by default, so there was no data for days 8-60.

---

## ✅ Solution

Added a **days parameter** to `topic_stat_daily` while keeping 7 days as the default:

```bash
# Default: 7 days (backward compatible)
rake topic_stat_daily

# Custom range: 60 days (for PDF reports)
rake 'topic_stat_daily[60]'

# Any custom range
rake 'topic_stat_daily[30]'
```

---

## 📝 Implementation Details

### File: `lib/tasks/topic_stat_daily.rake`

**Before:**
```ruby
task topic_stat_daily: :environment do
  var_date = DAYS_RANGE.days.ago.to_date..Date.today  # Always 7 days
```

**After:**
```ruby
task :topic_stat_daily, [:days] => :environment do |_t, args|
  days = args[:days].presence ? Integer(args[:days]) : (DAYS_RANGE || 7)
  var_date = days.days.ago.to_date..Date.today  # Configurable!
```

---

## 📅 Scheduler Updates

### Daily (3 AM):
```ruby
rake topic_stat_daily  # 7 days (default) - keeps recent data fresh
```

### Weekly (Sunday 5 AM):
```ruby
rake 'topic_stat_daily[60]'  # 60 days - for PDF report support
```

**Schedule Order:**
- 3 AM: Daily tagger (60 days)
- 4 AM: Weekly sync_all (60 days)
- 5 AM: **NEW** topic_stat_daily (60 days) ← Updates charts!
- 6 AM: Health check

---

## 🔄 What This Task Does

For each active topic, for each day in the range:

1. **Count entries** by tag for the day
2. **Sum interactions** for the day
3. **Calculate average** interactions per entry
4. **Break down by sentiment**: positive, neutral, negative counts and interactions
5. **Save to `topic_stat_dailies`** table

This data is then used by:
- PDF temporal charts
- Dashboard time-series graphs
- Historical trend analysis

---

## 📊 Data Flow

```
Entry (raw data)
    ↓ tagged with topic tags
    ↓ aggregated by date
    ↓
TopicStatDaily (daily aggregates)
    ↓ used by
    ↓
PDF Service → Temporal Charts
Dashboard Service → Time-series Graphs
```

---

## 🚀 Usage

### For a Specific Issue (Like Topic 264):

```bash
# Immediate fix: update 60 days of stats
RAILS_ENV=production rake 'topic_stat_daily[60]'

# Then verify PDF
# https://morfeo.com.py/topic/264/pdf?days_range=60
```

### For All Topics:

```bash
# Update all active topics for 60 days
RAILS_ENV=production rake 'topic_stat_daily[60]'
```

### For Maintenance:

```bash
# Daily: Keep last 7 days fresh
RAILS_ENV=production rake topic_stat_daily

# Weekly: Update full 60-day range
RAILS_ENV=production rake 'topic_stat_daily[60]'
```

---

## 🔍 Verification

### Check if Stats Exist:

```bash
RAILS_ENV=production rails console

# Check topic 264 stats for last 60 days
> TopicStatDaily.where(topic_id: 264)
                .where('topic_date >= ?', 60.days.ago.to_date)
                .count
# Should return: ~60 rows (one per day)

# Check specific date
> TopicStatDaily.find_by(topic_id: 264, topic_date: Date.today - 30.days)
# Should return: a record with entry_count, total_count, etc.
```

### Check PDF:

```bash
# Open PDF with 60-day range
https://morfeo.com.py/topic/264/pdf?days_range=60

# Verify:
# 1. Total count is correct (e.g., 317)
# 2. Temporal chart shows all 60 days
# 3. Chart has data points for older dates
```

---

## ⏰ When to Run

### Automatically (Scheduled):
- **Daily 3 AM**: 7 days (via schedule.rb)
- **Weekly Sunday 5 AM**: 60 days (via schedule.rb)

### Manually:
- **After adding tags to a topic** → Wait for auto-sync, then run stats
- **Before generating 60-day PDF report** → Run stats if data looks stale
- **When temporal charts are empty** → Run stats to regenerate
- **After bulk data imports** → Run stats to aggregate new data

---

## 🐛 Troubleshooting

### PDF Shows Only 7 Days Despite 60-Day URL:

```bash
# The stats table only has 7 days
# Solution: Update stats for 60 days
rake 'topic_stat_daily[60]'
```

### Total Count Correct, But Chart Empty:

```bash
# The entries exist, but stats aren't aggregated
# Solution: Regenerate stats
rake 'topic_stat_daily[60]'
```

### Stats Not Updating After New Entries:

```bash
# New entries need to be aggregated
# Solution: Run daily stats
rake topic_stat_daily  # or with specific days
```

---

## 📈 Performance

### Execution Time:

- **7 days, all topics**: ~5-10 minutes
- **60 days, all topics**: ~30-60 minutes
- **60 days, single topic**: ~30-60 seconds (if you modify to support single topic)

### Database Impact:

- **Reads**: One query per topic per day
- **Writes**: One insert/update per topic per day
- **Table Size**: ~365 rows per topic per year (manageable)

---

## 🔗 Related Documentation

- [TOPIC_UPDATE_TASK.md](./TOPIC_UPDATE_TASK.md) - Full topic update (includes this + sync)
- [PDF_IMPLEMENTATION_GUIDE.md](../guides/PDF_IMPLEMENTATION_GUIDE.md) - PDF generation system
- [RAKE_TASKS_QUICK_REFERENCE.md](../../RAKE_TASKS_QUICK_REFERENCE.md) - All rake tasks

---

## ✅ Summary

| Aspect | Before | After |
|--------|--------|-------|
| Default Range | 7 days | 7 days ✅ (backward compatible) |
| Custom Range | ❌ Not possible | ✅ Any range (e.g., 60) |
| PDF 60-day charts | ❌ Only 7 days shown | ✅ Full 60 days shown |
| Scheduler | Daily 7 days only | Daily 7 + Weekly 60 |
| Manual Usage | Only 7 days | Configurable days |

**Status**: ✅ Production ready - scheduled to run weekly at 5 AM Sundays


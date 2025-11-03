# PDF Reports - 60-Day Data Requirement

## 📋 Overview

Morfeo's PDF reports now support **4 date range options**:
- ✅ 7 days
- ✅ 15 days
- ✅ 30 days
- ✅ 60 days

To ensure all report variants generate correctly with accurate data, **topics must maintain at least 60 days of updated data**.

---

## 🎯 Why 60 Days?

### PDF Report Architecture

When a user clicks "Generar Reporte PDF", they can select from 4 time ranges:

```
┌─────────────────────────────────────┐
│  Generar Reporte PDF                │
│                                     │
│  [ 7 días  ] [ 15 días ]           │
│  [ 30 días ] [ 60 días ]           │
└─────────────────────────────────────┘
```

Each button generates a PDF with data scoped to that specific time range:

- **7 días**: `?days_range=7` → Shows last 7 days of data
- **15 días**: `?days_range=15` → Shows last 15 days of data
- **30 días**: `?days_range=30` → Shows last 30 days of data
- **60 días**: `?days_range=60` → Shows last 60 days of data

### The Problem

If your topic only has **30 days** of updated data:
- ✅ 7-day report: Works (data exists)
- ✅ 15-day report: Works (data exists)
- ✅ 30-day report: Works (data exists)
- ❌ **60-day report: INCOMPLETE** (only shows 30 days)

This creates inconsistent user experience and incorrect CEO-level insights.

### The Solution

**Maintain 60 days of data** for all active topics:
- ✅ All 4 report ranges work perfectly
- ✅ Consistent data across all time frames
- ✅ CEOs can compare trends across different periods
- ✅ No "partial data" warnings needed

---

## 🔧 Implementation Changes

### 1. **Rake Task Updates**

The `topic:update` task now emphasizes 60-day updates:

```bash
# OLD approach (insufficient for 60-day reports)
rake 'topic:update[1,30]'

# NEW approach (recommended)
rake 'topic:update[1,60]'
```

> **Note**: Single quotes are required for zsh compatibility. If using bash, quotes are optional.

**What changed**:
- Help text now shows all 4 ranges (7, 15, 30, 60)
- Examples emphasize 60 days as recommended
- Warnings added for PDF report compatibility

### 2. **Documentation Updates**

All documentation now recommends 60-day updates:

**Files updated**:
- `lib/tasks/update_topic.rake` - Task implementation
- `docs/TOPIC_UPDATE_TASK.md` - Full task documentation
- `RAKE_TASKS_QUICK_REFERENCE.md` - Quick reference guide
- `docs/PDF_REPORTS_60_DAY_REQUIREMENT.md` - This file

### 3. **Service Layer**

Services already support dynamic date ranges via `days_range` parameter:

```ruby
# All services support custom date ranges
DigitalDashboardServices::AggregatorService.call(
  topic: topic,
  days_range: 60  # Can be 7, 15, 30, or 60
)
```

### 4. **Controllers**

Controllers correctly pass `days_range` to services:

```ruby
# In pdf action
@days_range = (params[:days_range].presence&.to_i || DAYS_RANGE || 7)

dashboard_data = DigitalDashboardServices::AggregatorService.call(
  topic: @topic,
  days_range: @days_range  # Dynamic based on user selection
)
```

### 5. **Cache Keys**

All cache keys now include `days_range` for proper segmentation:

```ruby
# Each days_range has its own cache entry
"digital_dashboard_#{@topic.id}_#{@days_range}_#{Date.current}"
# Example: "digital_dashboard_1_7_2025-11-03"
# Example: "digital_dashboard_1_15_2025-11-03"
# Example: "digital_dashboard_1_30_2025-11-03"
# Example: "digital_dashboard_1_60_2025-11-03"
```

---

## 📊 Data Requirements by Dashboard

### Digital Dashboard (Topic)
- **Sources**: News articles from scraped media
- **Data needed**: 60 days of entries with tags and topic associations
- **Update command**: `rake topic:update[TOPIC_ID,60]`

### Facebook Dashboard
- **Sources**: Facebook posts from monitored pages
- **Data needed**: 60 days of posts with tags
- **Update command**: `rake topic:update[TOPIC_ID,60]`

### Twitter Dashboard
- **Sources**: Twitter posts from monitored profiles
- **Data needed**: 60 days of tweets with tags
- **Update command**: `rake topic:update[TOPIC_ID,60]`

### General Dashboard
- **Sources**: Combined (Digital + Facebook + Twitter)
- **Data needed**: 60 days across all sources
- **Update command**: `rake topic:update[TOPIC_ID,60]`

---

## 🚀 Production Deployment Checklist

### Before Deploying to Production

- [ ] **Update all active topics with 60 days of data**
  ```bash
  RAILS_ENV=production rake 'topic:update_all[60]'
  ```

- [ ] **Verify data completeness for each topic**
  ```bash
  RAILS_ENV=production rails console
  > Topic.where(status: true).each do |topic|
  >   count = topic.entries.where(published_at: 60.days.ago..Time.current).count
  >   puts "#{topic.name}: #{count} entries in last 60 days"
  > end
  ```

- [ ] **Test PDF generation for all 4 ranges**
  - Visit each topic dashboard
  - Generate PDF for 7, 15, 30, and 60 days
  - Verify data appears correctly in all reports

- [ ] **Update cron schedule for 60-day maintenance**
  ```ruby
  # In config/schedule.rb
  every 1.day, at: '2:00 AM' do
    rake "topic:update[1,60]"  # Critical topics
  end
  
  every :sunday, at: '3:00 AM' do
    rake "topic:update_all[60]"  # All topics
  end
  ```

- [ ] **Clear all caches after update**
  ```bash
  RAILS_ENV=production rake cache:clear
  ```

- [ ] **Warm caches for all topics**
  ```bash
  RAILS_ENV=production rake cache:warm_dashboards
  ```

---

## ⏱️ Performance Considerations

### Update Time Estimates

| Operation | Time | Notes |
|-----------|------|-------|
| Single topic (7 days) | 30-90 sec | Fast for recent data |
| Single topic (60 days) | 4-10 min | Processes 8x more data |
| All topics (60 days) | 60-120 min | Depends on topic count |

### Storage Impact

**60 days vs 7 days**:
- ~8x more database records cached
- ~8x more Redis cache memory
- ~8x longer initial processing time

**Mitigation**:
- Caching reduces repeated processing cost
- Background jobs can run updates during off-hours
- Redis TTL expires old caches automatically

### Memory Requirements

**Recommended**:
- Redis: At least 2GB for 20+ active topics
- MySQL: Adequate for tag-based queries with proper indexing
- Ruby: Standard Rails memory footprint

---

## 🔍 Monitoring & Validation

### Check Data Completeness

```ruby
# Rails console
topic = Topic.find(1)

# Count entries per date range
[7, 15, 30, 60].each do |days|
  count = topic.entries.where(published_at: days.days.ago..Time.current).count
  puts "Last #{days} days: #{count} entries"
end
```

**Expected output**:
```
Last 7 days: 45 entries
Last 15 days: 89 entries
Last 30 days: 178 entries
Last 60 days: 342 entries  ✅ Should be the largest
```

### Check Cache Coverage

```ruby
# Rails console
topic_id = 1

# Check if caches exist for all ranges
[7, 15, 30, 60].each do |days|
  key = "digital_dashboard_#{topic_id}_#{days}_#{Date.current}"
  exists = Rails.cache.exist?(key)
  puts "#{days} days cache: #{exists ? '✅ EXISTS' : '❌ MISSING'}"
end
```

### Check PDF Generation

```bash
# Test each range via curl (replace with actual domain)
curl -I "https://morfeo.com.py/topic/1/pdf?days_range=7"
curl -I "https://morfeo.com.py/topic/1/pdf?days_range=15"
curl -I "https://morfeo.com.py/topic/1/pdf?days_range=30"
curl -I "https://morfeo.com.py/topic/1/pdf?days_range=60"

# All should return 200 OK
```

---

## 🆘 Troubleshooting

### Issue: 60-day PDF shows only 30 days of data

**Cause**: Topic not updated with 60 days of data

**Solution**:
```bash
rake topic:update[TOPIC_ID,60]
rails cache:clear
```

### Issue: 60-day update takes too long

**Cause**: Large volume of entries to process

**Solution**:
- Run during off-peak hours
- Use background job (Sidekiq)
- Consider updating in smaller batches

### Issue: Cache not working for 60-day range

**Cause**: Cache key mismatch or not including `days_range`

**Solution**:
- Verify cache key includes `days_range`
- Clear and regenerate cache
- Check Redis memory limits

---

## 📝 Best Practices

### Daily Operations

1. **Critical Topics** (high visibility):
   ```bash
   # Update daily with full 60-day range
   rake 'topic:update[TOPIC_ID,60]'
   ```

2. **Regular Topics** (standard monitoring):
   ```bash
   # Update weekly with 60-day range
   rake 'topic:update[TOPIC_ID,60]'
   ```

3. **Seasonal Topics** (campaigns, events):
   ```bash
   # Update before/after events with 60-day range
   rake 'topic:update[TOPIC_ID,60]'
   ```

### Before Important Presentations

```bash
# Ensure all topics have fresh 60-day data
rake 'topic:update_all[60]'

# Clear and warm caches
rake cache:clear
rake cache:warm_dashboards

# Verify PDF generation works
# Manually test each critical topic's PDFs
```

### After System Changes

```bash
# After adding new tags
rake 'topic:update[TOPIC_ID,60]'

# After algorithm updates
rake 'topic:update_all[60]'

# After data imports
rake 'topic:update[TOPIC_ID,60]'
```

---

## 🎓 Training Materials

### For Administrators

**Key Points**:
- PDF reports need 60 days of data
- Run `topic:update[ID,60]` for complete coverage
- Schedule weekly 60-day updates via cron
- Monitor data completeness regularly

### For Developers

**Key Points**:
- All services support `days_range` parameter
- Cache keys must include `days_range`
- Use `.distinct.count` for accurate counts
- Test all 4 date ranges when modifying code

### For CEOs/End Users

**Key Points**:
- 4 report options: 7, 15, 30, 60 days
- All ranges show accurate data
- Data updated automatically via scheduled jobs
- Contact admin if reports show "no data"

---

## 🔗 Related Documentation

- **Task Documentation**: `/docs/TOPIC_UPDATE_TASK.md`
- **Quick Reference**: `/RAKE_TASKS_QUICK_REFERENCE.md`
- **Caching Strategy**: `/docs/CACHING_STRATEGY.md`
- **System Architecture**: `/docs/SYSTEM_ARCHITECTURE.md`

---

## ✅ Success Criteria

Your 60-day implementation is successful when:

- ✅ All 4 PDF ranges (7, 15, 30, 60) generate correctly
- ✅ Each range shows accurate, complete data
- ✅ PDFs generate within 5 seconds (cached)
- ✅ No "partial data" or "insufficient data" errors
- ✅ CEOs can compare trends across different time periods
- ✅ Automated updates maintain 60-day data window

---

**Summary**: Always maintain 60 days of data for topics with PDF reporting to ensure all report variants (7, 15, 30, 60 days) function correctly.

**Quick Command**: `rake 'topic:update[TOPIC_ID,60]'`

> **Note**: Single quotes are required for zsh compatibility. If using bash, quotes are optional.

**Last Updated**: November 3, 2025  
**Status**: ✅ Production Ready


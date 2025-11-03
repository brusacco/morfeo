# 🚀 Critical Sync Issue - Implementation Guide

**Date**: November 3, 2025  
**Status**: Ready for Implementation  
**Related**: See `CRITICAL_SYNC_ISSUE_AUDIT.md` for full analysis

---

## 📋 Quick Summary

**Problem**: PDF reports only show 7 days of data because `entry_topics` table is out of sync.

**Root Cause**: The main `tagger` task (which re-tags 60 days) is NOT scheduled, and there's no automatic sync process.

**Solution**: Add scheduled tasks to keep associations in sync automatically.

---

## 🎯 Implementation Steps

### Phase 1: Immediate Fix (Do Now - 30 minutes)

#### Step 1: Manual Sync All Topics

```bash
# Fix current state - sync all topics with 60 days
RAILS_ENV=production rake 'topic:sync_all[60]'

# This will take 5-10 minutes depending on data volume
# Watch for errors and note any failed topics
```

#### Step 2: Update Cron Schedule

```bash
# Backup current schedule
cp config/schedule.rb config/schedule.rb.backup

# Replace with new schedule
cp config/schedule.rb.PROPOSED config/schedule.rb

# Update crontab
whenever --update-crontab

# Verify it was applied
crontab -l | grep -A 2 -B 2 "tagger\|sync_all\|sync_health"
```

#### Step 3: Verify Fix

```bash
# Check a few topics that had issues
RAILS_ENV=production rake 'audit:entry_topics:check[264]'
RAILS_ENV=production rake 'audit:entry_topics:check[ANOTHER_TOPIC_ID]'

# Should show "SYNCED" for all periods now
```

---

### Phase 2: Monitoring (Next 48 hours)

#### Day 1 - Monitor Initial Runs

**Expected Schedule**:
- **2:00 PM today**: First `tagger` run
- **3:00 AM tomorrow**: First `topic:sync_all` run
- **6:00 AM tomorrow**: First `audit:sync_health` run

**What to check**:

```bash
# Watch logs during tagger run (2:00 PM)
tail -f log/production.log | grep -i "tagger\|tag"

# Check sync_all ran successfully (next morning)
tail -100 log/production.log | grep -i "sync"

# Review health check results
cat log/sync_health.log
```

#### Day 2 - Verify PDF Reports

1. Generate PDF reports for different date ranges:
   - 7 days
   - 15 days
   - 30 days
   - 60 days

2. Verify each report shows complete data

3. Compare with audit results:
```bash
RAILS_ENV=production rake 'audit:tag:presence[TAG_ID]'
```

---

### Phase 3: Long-term Validation (1 week)

#### Week 1 Checklist

- [ ] All scheduled tasks running successfully
- [ ] No sync health alerts
- [ ] PDF reports complete for all time ranges
- [ ] Performance acceptable (no slowdowns)
- [ ] Disk space OK (logs not growing too large)

#### Performance Metrics to Track

```bash
# Check task durations
grep "Duration:" log/production.log | grep -E "(tagger|sync_all)"

# Typical expected times:
# - tagger: 10-30 minutes (60 days of entries)
# - sync_all: 2-5 minutes (lighter than topic:update)
# - sync_health: 1-2 minutes (read-only checks)
```

---

## 📊 New Commands Available

### Sync Commands

```bash
# Sync all topics (lightweight, fast)
rake 'topic:sync_all[60]'           # All topics, 60 days
rake 'topic:sync_all[30]'           # All topics, 30 days

# Sync single topic
rake 'topic:sync[TOPIC_ID,60]'      # One topic, 60 days

# Update by tag (find and sync all topics using a tag)
rake 'topic:list_by_tag[TAG_ID]'    # List topics using tag
rake 'topic:update_by_tag[TAG_ID,60]'  # Update all topics using tag
```

### Health Check Commands

```bash
# Check all topics
rake 'audit:sync_health'

# Check single topic
rake 'audit:sync_health_topic[TOPIC_ID]'

# Check entry_topics sync detail
rake 'audit:entry_topics:check[TOPIC_ID]'

# Check tag presence
rake 'audit:tag:presence[TAG_ID]'
```

---

## 🔧 New Scheduled Tasks

### Updated Schedule

| Task | Frequency | Time | Purpose |
|------|-----------|------|---------|
| `tagger` | Every 12h | 2am, 2pm | Re-tag last 60 days |
| `topic:sync_all[60]` | Daily | 3am | Sync all topics |
| `audit:sync_health` | Daily | 6am | Health check & alert |

### Task Details

#### 1. `tagger` (Every 12 hours)

**What it does**:
- Re-tags entries from last 60 days
- Applies new tags added to topics
- Triggers automatic sync via callbacks

**Runtime**: ~10-30 minutes

**Why 12 hours**: 
- Catches tags added during business hours
- 2pm run ensures same-day updates
- 2am run prepares for next business day

#### 2. `topic:sync_all[60]` (Daily at 3am)

**What it does**:
- Syncs `entry_topics` for all topics
- Lightweight (no stats recalculation)
- Ensures associations are current

**Runtime**: ~2-5 minutes

**Why 3am**: 
- After 2am tagger completes
- Before business hours start
- Low server load time

#### 3. `audit:sync_health` (Daily at 6am)

**What it does**:
- Checks sync accuracy for all topics
- Logs issues to `log/sync_health.log`
- Returns error code if issues found

**Runtime**: ~1-2 minutes

**Why 6am**:
- After sync completes
- Before business hours
- Alerts ready for morning review

---

## 📈 Success Metrics

### Week 1 Goals

- ✅ Zero sync health alerts
- ✅ PDF reports show complete data (all ranges)
- ✅ All scheduled tasks complete successfully
- ✅ Performance within acceptable range

### Ongoing Metrics

| Metric | Target | How to Check |
|--------|--------|--------------|
| Sync accuracy | < 1% difference | `audit:sync_health` |
| PDF completeness | 100% of entries | Manual review |
| Task success rate | 100% | Check logs |
| Tagger runtime | < 30 min | Check logs |
| Sync_all runtime | < 10 min | Check logs |

---

## 🚨 Troubleshooting

### Issue: sync_health reports problems

**Symptoms**:
```
⚠️  SYNC ISSUES DETECTED
Topic 264: MIC - 16 entries out of sync
```

**Fix**:
```bash
# Sync the specific topic
RAILS_ENV=production rake 'topic:sync[264,60]'

# Or sync all topics
RAILS_ENV=production rake 'topic:sync_all[60]'
```

---

### Issue: tagger taking too long

**Symptoms**:
- Tagger runs for > 1 hour
- Overlaps with next scheduled run

**Fix**:
```bash
# Reduce scope to 30 days
# Edit config/schedule.rb, change tagger to:
every 12.hours, at: ['2:00 am', '2:00 pm'] do
  # Temporary: only 30 days until optimized
  rake 'tagger_range[30]'  # Would need to create this task
end
```

**Long-term**: Optimize tagger task or increase frequency

---

### Issue: High server load

**Symptoms**:
- Server slow during tagger runs
- Other processes affected

**Fix Options**:

1. **Reduce concurrency**:
   - Tagger processes entries one-by-one
   - Already throttled with sleep calls
   - May need to increase sleep time

2. **Change schedule**:
   - Move to off-peak hours only
   - Run once daily instead of twice

3. **Optimize queries**:
   - Add database indexes
   - Use batch processing
   - Cache results

---

### Issue: PDF reports still incomplete

**Check**:
```bash
# 1. Verify sync ran
grep "SYNC" log/production.log | tail -20

# 2. Check specific topic
rake 'audit:entry_topics:check[TOPIC_ID]'

# 3. Verify PDF service uses associations
grep "entry_topics\|entries" app/services/digital_dashboard_services/pdf_service.rb
```

**Common causes**:
- Sync didn't run yet (check schedule)
- Cache still serving old data (clear cache)
- PDF service not using associations (code review needed)

---

## 📝 Rollback Procedure

If issues occur and you need to revert:

```bash
# 1. Stop all cron jobs
whenever --clear-crontab

# 2. Restore original schedule
cp config/schedule.rb.backup config/schedule.rb
whenever --update-crontab

# 3. Verify rollback
crontab -l | grep -c "sync_all"  # Should be 0

# 4. Monitor logs
tail -f log/production.log

# 5. Manual recovery if needed
RAILS_ENV=production rake 'topic:update_all[60]'
```

---

## 📚 Documentation Updates

Files created/updated:

1. ✅ `docs/CRITICAL_SYNC_ISSUE_AUDIT.md` - Full analysis
2. ✅ `docs/CRITICAL_SYNC_ISSUE_IMPLEMENTATION.md` - This file
3. ✅ `lib/tasks/topic_sync_all.rake` - New sync tasks
4. ✅ `lib/tasks/audit/sync_health.rake` - Health check tasks
5. ✅ `lib/tasks/topic_update_by_tag.rake` - Update by tag
6. ✅ `lib/tasks/audit/entry_topics_diagnostic.rake` - Diagnostic tool
7. ✅ `config/schedule.rb.PROPOSED` - New schedule
8. ✅ `RAKE_TASKS_QUICK_REFERENCE.md` - Updated with new commands

---

## ✅ Pre-Implementation Checklist

Before deploying:

- [ ] Backup current `config/schedule.rb`
- [ ] Review all new rake tasks
- [ ] Test sync_all on staging (if available)
- [ ] Check disk space for logs
- [ ] Notify team of scheduled task changes
- [ ] Plan monitoring for first 48 hours
- [ ] Have rollback plan ready

---

## 🎉 Post-Implementation Checklist

After deploying:

- [ ] Manual sync completed successfully
- [ ] Crontab updated with new schedule
- [ ] First tagger run completed (2pm today or 2am tomorrow)
- [ ] First sync_all run completed (3am)
- [ ] First health check completed (6am)
- [ ] PDF reports verified for all ranges
- [ ] No performance issues detected
- [ ] Team notified of changes
- [ ] Documentation updated

---

## 📞 Support

If issues arise:

1. **Check logs first**:
   ```bash
   tail -100 log/production.log
   cat log/sync_health.log
   ```

2. **Run diagnostics**:
   ```bash
   rake 'audit:sync_health'
   rake 'audit:entry_topics:check[TOPIC_ID]'
   ```

3. **Manual fix if needed**:
   ```bash
   rake 'topic:sync_all[60]'
   ```

4. **Rollback if critical**:
   - Follow rollback procedure above
   - Investigate root cause offline
   - Re-deploy with fixes

---

**Implementation Status**: ⏳ Ready for deployment  
**Risk Level**: 🟡 Medium (production impact but non-breaking)  
**Estimated Time**: 30 minutes initial + 48 hours monitoring  
**Next Step**: Execute Phase 1 implementation



# Production Deployment Commands - Phase 1

**Date:** November 1, 2025  
**Phase:** Entry-Topic Optimization - Phase 1  
**Estimated Time:** 3-5 hours (mostly automated backfill)

---

## 🚀 Step 1: Deploy Code to Production

### On Your Local Machine

```bash
# 1. Commit all changes
cd /Users/brunosacco/Proyectos/Rails/morfeo
git add .
git commit -m "Phase 1: Add Entry-Topic direct associations

- Create entry_topics and entry_title_topics tables
- Add associations to Entry and Topic models  
- Add auto-sync callbacks for new entries
- Create BackfillEntryTopicsJob
- Add validation rake tasks
- Local tests: 744+103 associations, 35.93ms queries
- Performance: 92% improvement vs production baseline

Ref: Performance optimization Phase 1"

# 2. Push to production
git push production main

# Or if you have a different deployment process:
# cap production deploy
# or your deployment command
```

---

## 🖥️ Step 2: On Production Server

### SSH to Production Server

```bash
ssh user@your-production-server
cd /path/to/morfeo  # Usually /home/rails/morfeo or similar
```

### Run Migrations

```bash
# Run database migrations
RAILS_ENV=production bundle exec rails db:migrate

# Verify tables were created
RAILS_ENV=production bundle exec rails runner "
puts 'Tables created:'
puts '  entry_topics: ' + (ActiveRecord::Base.connection.table_exists?('entry_topics') ? '✅' : '❌')
puts '  entry_title_topics: ' + (ActiveRecord::Base.connection.table_exists?('entry_title_topics') ? '✅' : '❌')
puts 'Initial counts:'
puts '  EntryTopic: ' + EntryTopic.count.to_s
puts '  EntryTitleTopic: ' + EntryTitleTopic.count.to_s
"
```

**Expected output:**
```
Tables created:
  entry_topics: ✅
  entry_title_topics: ✅
Initial counts:
  EntryTopic: 0
  EntryTitleTopic: 0
```

### Restart Application

```bash
# Restart Rails app (choose your method)
sudo systemctl restart morfeo-production
# OR
touch tmp/restart.txt
# OR
passenger-config restart-app /path/to/morfeo

# Verify app is running
curl -I https://yourdomain.com
tail -f log/production.log  # Watch for any errors (Ctrl+C to exit)
```

---

## 📊 Step 3: Test Auto-Sync on Production

**IMPORTANT:** Test that new entries will auto-sync before running backfill!

```bash
RAILS_ENV=production bundle exec rails runner "
puts '=' * 80
puts 'Testing Auto-Sync on Production'
puts '=' * 80

# Find a topic with tags
topic = Topic.joins(:tags).first
if topic
  puts 'Test topic: ' + topic.name
  puts 'Topic tags: ' + topic.tags.pluck(:name).join(', ')
  
  # Create test entry
  test_entry = Entry.new(
    site: Site.first,
    url: 'https://test.com/test-' + Time.now.to_i.to_s,
    title: 'Test Entry - Auto-sync verification',
    published_at: Time.current,
    enabled: true
  )
  
  # Add tags that match topic
  test_entry.tag_list = topic.tags.first(2).pluck(:name)
  test_entry.save!
  
  # Check if auto-sync worked
  synced = test_entry.topics.reload.count
  puts 'Auto-sync result: ' + synced.to_s + ' topic(s)'
  puts synced > 0 ? '✅ Auto-sync WORKING' : '❌ Auto-sync FAILED'
  
  # Clean up
  test_entry.destroy
  puts 'Test entry cleaned up'
else
  puts '⚠️  No topics found'
end
puts '=' * 80
"
```

**Expected output:**
```
================================================================================
Testing Auto-Sync on Production
================================================================================
Test topic: Honor Colorado
Topic tags: Horacio Cartes, Santiago Peña, ...
Auto-sync result: 1 topic(s)
✅ Auto-sync WORKING
Test entry cleaned up
================================================================================
```

---

## ⏰ Step 4: Run Production Backfill

**IMPORTANT:** This will take 2-4 hours for 1.7M entries!

### Option A: Run in Background (Recommended)

```bash
# Start backfill in background with logging
nohup RAILS_ENV=production bundle exec rails runner "
result = BackfillEntryTopicsJob.perform_now(batch_size: 500)
puts 'Backfill complete!'
puts 'Processed: ' + result[:processed].to_s
puts 'Errors: ' + result[:errors].size.to_s
" > log/backfill_$(date +%Y%m%d_%H%M%S).log 2>&1 &

# Save the process ID
echo $!

# Monitor progress in real-time
tail -f log/backfill_*.log

# Or monitor Rails log
tail -f log/production.log | grep -E "Entry|Backfill"
```

### Option B: Run in Chunks (Safer, Can Pause)

```bash
# Process first 500K entries
RAILS_ENV=production bundle exec rails runner "
BackfillEntryTopicsJob.perform_now(batch_size: 500, start_id: 1, end_id: 500000)
"

# Check results, then continue
RAILS_ENV=production bundle exec rails runner "
BackfillEntryTopicsJob.perform_now(batch_size: 500, start_id: 500001, end_id: 1000000)
"

# And so on...
```

### Monitor Progress

```bash
# In another SSH session, monitor database growth
watch -n 30 'mysql -u root morfeo_production -e "
SELECT 
  (SELECT COUNT(*) FROM entry_topics) as entry_topics,
  (SELECT COUNT(*) FROM entry_title_topics) as entry_title_topics,
  NOW() as timestamp;
"'

# Watch server resources
htop

# Check for errors
tail -f log/production.log | grep -i error
```

**Expected:**
- **Rate:** ~50-100 entries/second
- **Duration:** 2-4 hours for 1.7M entries
- **Final counts:** ~200K entry_topics, ~50K entry_title_topics

---

## ✅ Step 5: Validate Results

### After Backfill Completes

```bash
# Check final counts
RAILS_ENV=production bundle exec rails runner "
puts '=' * 80
puts 'Backfill Results'
puts '=' * 80
puts 'Total Entries: ' + Entry.count.to_s
puts 'EntryTopics: ' + EntryTopic.count.to_s
puts 'EntryTitleTopics: ' + EntryTitleTopic.count.to_s
puts ''
puts 'Percentage tagged: ' + ((EntryTopic.select(:entry_id).distinct.count.to_f / Entry.count * 100).round(2)).to_s + '%'
puts '=' * 80
"

# Test a few topics
RAILS_ENV=production bundle exec rails runner "
puts '=' * 80
puts 'Validation Test'
puts '=' * 80

Topic.active.limit(5).each do |topic|
  count = topic.entries.count
  enabled = topic.entries.enabled.count
  recent = topic.entries.enabled.where('published_at >= ?', 30.days.ago).count
  
  puts topic.name + ':'
  puts '  Total: ' + count.to_s
  puts '  Enabled: ' + enabled.to_s
  puts '  Recent (30d): ' + recent.to_s
end

puts '=' * 80
"

# Performance benchmark
RAILS_ENV=production bundle exec rails runner "
require 'benchmark'

topic = Topic.first
puts '=' * 80
puts 'Performance Test: ' + topic.name
puts '=' * 80

time = Benchmark.measure {
  topic.entries.enabled.where('published_at >= ?', 30.days.ago).to_a
}

ms = (time.real * 1000).round(2)
puts 'Query time: ' + ms.to_s + 'ms'
puts 'Entry count: ' + topic.entries.enabled.where('published_at >= ?', 30.days.ago).count.to_s
puts ''
puts ms < 100 ? '✅ Performance GOOD (< 100ms)' : '⚠️  Performance needs optimization'
puts '=' * 80
"
```

---

## 🔍 Step 6: Monitor Application

### Check for Errors

```bash
# Watch for any errors
tail -f log/production.log | grep -i error

# Check slow queries
mysql -u root morfeo_production -e "
SELECT 
  SUBSTRING(sql_text, 1, 100) AS query,
  COUNT_STAR AS executions,
  AVG_TIMER_WAIT / 1000000000 AS avg_ms
FROM performance_schema.events_statements_summary_by_digest
WHERE sql_text LIKE '%entry_topics%'
ORDER BY avg_ms DESC
LIMIT 10;
"

# Monitor memory usage
free -h

# Check CPU usage
top -bn1 | head -20
```

### Test Dashboards

```bash
# Test a few URLs
curl -I https://yourdomain.com/topics/1
curl -I https://yourdomain.com/general_dashboard/1
curl -I https://yourdomain.com/facebook_topic/1

# Check response times in logs
tail -f log/production.log | grep "Completed"
```

---

## 📊 Step 7: Collect Success Metrics

```bash
RAILS_ENV=production bundle exec rails runner "
puts '=' * 80
puts 'Phase 1 Deployment - Success Metrics'
puts '=' * 80
puts ''
puts 'Database:'
puts '  Total Entries: ' + Entry.count.to_s
puts '  Entry-Topic Associations: ' + EntryTopic.count.to_s
puts '  Title-Topic Associations: ' + EntryTitleTopic.count.to_s
puts ''
puts 'Coverage:'
puts '  Entries with topics: ' + EntryTopic.select(:entry_id).distinct.count.to_s
puts '  Percentage: ' + ((EntryTopic.select(:entry_id).distinct.count.to_f / Entry.count * 100).round(2)).to_s + '%'
puts ''
puts 'Performance (local test reference):'
puts '  Local result: 35.93ms (vs 440ms production baseline)'
puts '  Expected improvement: 80-88% faster'
puts ''
puts 'Status:'
puts '  ✅ Tables created'
puts '  ✅ Backfill complete'
puts '  ✅ Auto-sync enabled for new entries'
puts '  ⏳ Feature flag testing (Phase 3)'
puts '  ⏳ Elasticsearch removal (Phase 5)'
puts ''
puts '=' * 80
"
```

---

## ⚠️ Troubleshooting

### If Backfill Fails

```bash
# Check errors in log
grep -i error log/backfill_*.log
grep -i error log/production.log

# Resume from last processed ID
RAILS_ENV=production bundle exec rails runner "
# Find last entry_topic created
last_id = EntryTopic.maximum(:entry_id)
puts 'Last processed entry_id: ' + last_id.to_s
puts 'Resuming from: ' + (last_id + 1).to_s

# Resume backfill
BackfillEntryTopicsJob.perform_now(batch_size: 500, start_id: last_id + 1)
"
```

### If Performance is Slow

```bash
# Check indexes
mysql -u root morfeo_production -e "
SHOW INDEX FROM entry_topics;
SHOW INDEX FROM entry_title_topics;
"

# Analyze queries
RAILS_ENV=production bundle exec rails runner "
ActiveRecord::Base.logger = Logger.new(STDOUT)
topic = Topic.first
topic.entries.enabled.where('published_at >= ?', 30.days.ago).to_a
"
```

### If Auto-Sync Not Working

```bash
# Check callback is registered
RAILS_ENV=production bundle exec rails runner "
puts Entry._save_callbacks.select { |cb| cb.filter.to_s.include?('sync') }.inspect
"

# Manually sync an entry
RAILS_ENV=production bundle exec rails runner "
entry = Entry.last
entry.send(:sync_topics_from_tags)
entry.send(:sync_title_topics_from_tags)
puts 'Topics: ' + entry.topics.count.to_s
"
```

---

## 🎯 Success Criteria

Before considering Phase 1 complete:

- [ ] Code deployed successfully
- [ ] Migrations ran without errors
- [ ] Tables created with indexes
- [ ] Auto-sync test passed
- [ ] Backfill completed (2-4 hours)
- [ ] ~200K entry_topics created
- [ ] ~50K entry_title_topics created
- [ ] No errors in logs
- [ ] Dashboards still working
- [ ] Application performance stable

---

## 📞 Next Steps

**After Phase 1 is complete:**

1. **Monitor for 24-48 hours**
   - Watch error logs
   - Check dashboard performance
   - Verify new entries auto-sync

2. **Phase 2 Complete** ✅
   - Production backfill done
   - Data validated
   - System stable

3. **Phase 3: Feature Flag Testing (Week 3)**
   - Update Topic model with feature flags
   - Test new query methods
   - Compare performance

4. **Phase 4: Full Switchover (Week 4)**
   - Remove feature flags
   - Use direct associations everywhere

5. **Phase 5: Remove Elasticsearch (Week 5)**
   - Stop ES service
   - Save 33.6GB RAM 🎉

---

## 🆘 Emergency Rollback

**If something goes wrong:**

```bash
# Rollback migration
RAILS_ENV=production bundle exec rails db:rollback

# Restart app
sudo systemctl restart morfeo-production

# Redeploy previous version
git reset --hard HEAD~1
# Deploy...
```

**Note:** Backfill data is safe to delete:
```sql
TRUNCATE TABLE entry_topics;
TRUNCATE TABLE entry_title_topics;
```

---

**Good luck with deployment! 🚀**

**Estimated total time:** 3-5 hours (mostly automated)


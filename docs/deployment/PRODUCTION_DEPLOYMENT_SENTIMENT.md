# Production Deployment Guide - Sentiment Analysis

## ⚡ Parallel Processing Implemented

The rake tasks now use **5 parallel workers** for ultra-fast processing!

### 📊 Performance Metrics

| Environment | Entries | Time | Speed |
|-------------|---------|------|-------|
| **Development** | 3,005 | 0.2 min | 237 entries/sec |
| **Production (estimated)** | 38,836 | ~2.7 min | 237 entries/sec |

**Previous estimate:** 60-90 minutes  
**New estimate:** ~3 minutes ⚡  
**Speed improvement:** ~30x faster!

---

## 🚀 Deployment Steps

### Option 1: Zero Downtime (Recommended)

```bash
# 1. Deploy code
cd /path/to/morfeo
git pull origin main
bundle install
RAILS_ENV=production rails db:migrate

# 2. Restart server
touch tmp/restart.txt

# 3. Run parallel recalculation (takes ~3 minutes)
RAILS_ENV=production rails facebook:recalculate_sentiment

# Expected output:
# 🚀 Starting parallel sentiment recalculation...
#    Workers: 5
#    Total entries: 38836
# 
# ✅ Recalculation complete!
#    Processed: 38836/38836
#    Time: 2.7 minutes
#    Rate: 237.0 entries/second

# 4. Clear cache
RAILS_ENV=production rails runner "Rails.cache.clear"
```

### Option 2: Background Processing (Optional)

If you prefer to run it in background:

```bash
# After deploying, run in background
nohup rails facebook:recalculate_sentiment RAILS_ENV=production > tmp/sentiment_$(date +%Y%m%d_%H%M%S).log 2>&1 &

# Monitor progress
tail -f tmp/sentiment_*.log
```

**Note:** With 5 parallel workers completing in ~3 minutes, background processing is optional.

---

## ✅ What Changed

### Parallel Processing Features

1. **5 Concurrent Workers**
   - Processes 5 batches simultaneously
   - Each batch contains 500 entries
   - Automatic database reconnection per worker

2. **Accurate Progress Tracking**
   - Shows total processed entries
   - Displays processing rate (entries/sec)
   - Shows total time elapsed

3. **Error Handling**
   - Each worker handles errors independently
   - Failed entries are logged
   - Processing continues even if some entries fail

### Technical Implementation

```ruby
# Batches of 500, processed by 5 workers in parallel
Parallel.map_with_index(batches, in_processes: 5) do |batch, batch_idx|
  ActiveRecord::Base.connection.reconnect!
  
  batch.each do |entry_id|
    entry = FacebookEntry.find(entry_id)
    entry.calculate_sentiment_analysis
    entry.save!
  end
  
  { processed: batch.size }
end
```

---

## 🔍 Verification

After deployment, verify everything is working:

```bash
# 1. Check sample entry
rails runner "
  entry = FacebookEntry.where('reactions_total_count > 0').first
  puts 'Emotional Intensity: ' + entry.emotional_intensity.to_s + '%'
  puts 'Confidence: ' + (entry.sentiment_confidence * 100).round.to_s + '%'
" RAILS_ENV=production

# Expected output:
# Emotional Intensity: 48.44%
# Confidence: 76%

# 2. Check that all entries are updated (emotional_intensity < 100)
rails runner "
  total = FacebookEntry.where('reactions_total_count > 0').count
  updated = FacebookEntry.where('reactions_total_count > 0')
                        .where('emotional_intensity < 100')
                        .count
  
  if updated == total
    puts '✅ All entries updated successfully!'
  else
    puts '⚠️ Some entries pending: #{updated}/#{total}'
  end
" RAILS_ENV=production

# 3. Check topic summary
rails runner "
  topic = Topic.first
  summary = topic.facebook_sentiment_summary
  if summary && summary[:statistical_validity]
    v = summary[:statistical_validity]
    puts 'Overall Confidence: ' + (v[:overall_confidence] * 100).round.to_s + '%'
    puts 'Total Posts: ' + v[:total_posts].to_s
  end
" RAILS_ENV=production
```

---

## 📋 Deployment Checklist

- [ ] **Backup database** (recommended, though migration is non-destructive)
- [ ] **Deploy code:** `git pull && bundle install`
- [ ] **Run migrations:** `rails db:migrate RAILS_ENV=production`
- [ ] **Restart server:** `touch tmp/restart.txt`
- [ ] **Run rake task:** `rails facebook:recalculate_sentiment RAILS_ENV=production` (~3 minutes)
- [ ] **Clear cache:** `rails runner "Rails.cache.clear" RAILS_ENV=production`
- [ ] **Verify:** Check sample entries and topic summary
- [ ] **Monitor:** Check error logs for any issues

---

## ⚠️ Important Notes

### When to Run the Rake Task

✅ **YES - Run once now:**
- To update emotional intensity formula for existing data
- Changes from ratio (1.2, 2.5) to percentage (45%, 60%)

❌ **NO - Don't schedule it:**
- New posts calculate automatically via callback
- No need for recurring task
- Only run again if you change formulas

### System Requirements

The parallel processing uses:
- **5 processes** (manageable on most servers)
- **Minimal memory** (processes entries in batches)
- **Standard database load** (saves occur sequentially per worker)

Safe for production servers with:
- 2+ CPU cores
- 2+ GB RAM available
- Standard MySQL configuration

---

## 🎯 Expected Timeline

| Step | Duration | Can Run in BG? |
|------|----------|----------------|
| Code deployment | ~1 min | No |
| Database migration | ~10 sec | No |
| Server restart | ~10 sec | No |
| Rake recalculation | **~3 min** | Yes (optional) |
| Cache clear | ~5 sec | No |
| **Total** | **~5 minutes** | |

**Recommended deployment window:** Anytime (no downtime needed)

---

## 🚨 Troubleshooting

### If rake task fails

```bash
# Check error logs
tail -f log/production.log

# Try with single worker (debug mode)
RAILS_ENV=production rails facebook:calculate_sentiment

# Check database connection
rails runner "puts ActiveRecord::Base.connection.active?" RAILS_ENV=production
```

### If results look incorrect

```bash
# Verify sample entries
rails runner "
  FacebookEntry.where('reactions_total_count > 0').limit(5).each do |e|
    puts 'ID: ' + e.id.to_s
    puts '  Reactions: ' + e.reactions_total_count.to_s
    puts '  Emotional Intensity: ' + e.emotional_intensity.to_s + '%'
    puts '  Sentiment Score: ' + e.sentiment_score.to_s
    puts ''
  end
" RAILS_ENV=production
```

---

## 📊 Success Metrics

After deployment, you should see:

✅ All emotional intensity values between 0-100 (percentages)  
✅ Processing rate: ~200-250 entries/second  
✅ Total time: 2-4 minutes for 38,836 entries  
✅ No errors in logs  
✅ Sentiment charts displaying correctly  
✅ Confidence levels showing on posts  

---

## 🎉 Summary

**With 5 parallel workers, your 38,836 entries will be processed in ~3 minutes!**

This is a **30x improvement** over the original estimate of 60-90 minutes.

The deployment is safe, fast, and requires no downtime. 🚀


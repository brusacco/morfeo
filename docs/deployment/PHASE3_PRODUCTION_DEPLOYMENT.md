# Phase 3: Production Deployment Guide

## ✅ Local Testing Complete
- [x] Feature flag working with ENV
- [x] All MySQL ONLY_FULL_GROUP_BY errors fixed
- [x] Dashboard works with Elasticsearch stopped
- [x] Direct associations functional

---

## 🚀 Production Deployment Steps

### **Step 1: Deploy Code Changes**

```bash
# SSH to production server
ssh user@production-server

# Navigate to app directory
cd /path/to/morfeo

# Pull latest changes
git pull origin main

# Install any new dependencies (if needed)
bundle install

# Run migrations (they should already be run, but just in case)
RAILS_ENV=production bin/rails db:migrate

# Restart application
# (Use your deployment method - systemd, passenger, etc.)
sudo systemctl restart morfeo-production
# OR
touch tmp/restart.txt
```

---

### **Step 2: Set Feature Flag (START WITH FALSE)**

**IMPORTANT**: Start with `USE_DIRECT_ENTRY_TOPICS=false` to ensure current behavior works

```bash
# Method 1: Export in shell (temporary - for testing)
export USE_DIRECT_ENTRY_TOPICS=false

# Method 2: Add to systemd service (permanent - recommended)
sudo nano /etc/systemd/system/morfeo-production.service
# Add line:
# Environment="USE_DIRECT_ENTRY_TOPICS=false"
sudo systemctl daemon-reload
sudo systemctl restart morfeo-production

# Method 3: Add to .env file (if using dotenv in production)
echo "USE_DIRECT_ENTRY_TOPICS=false" >> .env
sudo systemctl restart morfeo-production
```

---

### **Step 3: Test with Feature Flag OFF (Elasticsearch)**

```bash
# Test that existing behavior still works
curl -I https://your-domain.com/topics/1
# Should return 200 OK

# Check logs for any errors
tail -f log/production.log

# Monitor Elasticsearch usage
htop
# Look for elasticsearch/java process - should still be using memory
```

**Expected**:
- ✅ Dashboard loads normally
- ✅ Elasticsearch still in use (~33GB RAM)
- ✅ All existing functionality works

---

### **Step 4: Enable Feature Flag (Switch to Direct Associations)**

```bash
# Update the environment variable
export USE_DIRECT_ENTRY_TOPICS=true

# OR update systemd service
sudo nano /etc/systemd/system/morfeo-production.service
# Change to: Environment="USE_DIRECT_ENTRY_TOPICS=true"
sudo systemctl daemon-reload
sudo systemctl restart morfeo-production

# OR update .env file
sed -i 's/USE_DIRECT_ENTRY_TOPICS=false/USE_DIRECT_ENTRY_TOPICS=true/' .env
sudo systemctl restart morfeo-production
```

**Clear Rails cache after enabling**:
```bash
RAILS_ENV=production bin/rails runner "Rails.cache.clear; puts 'Cache cleared!'"
```

---

### **Step 5: Test with Feature Flag ON (Direct Associations)**

```bash
# Test dashboard loads
curl -I https://your-domain.com/topics/1
# Should return 200 OK

# Check logs for performance improvements
tail -f log/production.log
# Look for SQL query times - should be faster

# Test multiple topics
for i in {1..10}; do
  echo "Testing topic $i..."
  curl -s -o /dev/null -w "Topic $i: %{time_total}s\n" https://your-domain.com/topics/$i
done
```

**Expected**:
- ✅ Dashboard loads **faster** (50-100ms vs 440ms)
- ✅ SQL queries show direct JOINs (not Elasticsearch)
- ✅ Elasticsearch no longer queried for Entry lookups
- ⚠️ Elasticsearch still running (but usage should drop)

---

### **Step 6: Monitor Server Resources**

```bash
# Monitor memory usage over 15-30 minutes
watch -n 5 'free -h && echo "" && ps aux | grep -E "mysql|java|elastic" | grep -v grep'

# Check MySQL query performance
mysql -u root -p -e "SHOW PROCESSLIST;"

# Monitor application logs
tail -f log/production.log | grep -E "Completed|SQL"
```

**What to Look For**:
- 🔍 MySQL memory might increase slightly (expected - more queries)
- 🔍 Elasticsearch memory should stay same (not queried, but still indexing)
- 🔍 Response times should improve (200-300ms → 100-200ms)
- 🔍 No errors in logs

---

### **Step 7: Performance Validation**

Run this benchmark on production:

```bash
RAILS_ENV=production bin/rails runner "
require 'benchmark'

topic = Topic.first
puts '=' * 80
puts 'Production Performance Test: ' + topic.name
puts '=' * 80

# Test list_entries performance
time = Benchmark.measure do
  entries = topic.list_entries.to_a
  puts 'Entries loaded: ' + entries.size.to_s
end

puts 'Time: ' + (time.real * 1000).round(2).to_s + 'ms'
puts '=' * 80
puts 'Expected: < 250ms (vs 440ms before)'
puts 'Success!' if time.real * 1000 < 250
puts '=' * 80
"
```

**Success Criteria**:
- ✅ Query completes in < 250ms
- ✅ Returns correct number of entries
- ✅ No SQL errors in logs

---

## 🎯 Expected Results

| Metric | Before (Elasticsearch) | After (Direct Associations) | Target |
|--------|------------------------|----------------------------|--------|
| **Query Time** | 440ms | 100-200ms | < 250ms |
| **Elasticsearch Queries** | High (every page load) | Zero (for entries) | 0 |
| **MySQL Load** | Low | Moderate (acceptable) | Stable |
| **Memory (ES)** | 33.6GB | 33.6GB (still indexing) | Same |
| **Memory (MySQL)** | 69.5GB | 69.5GB - 75GB | < 80GB |

---

## 🚨 Rollback Plan (If Issues Occur)

If you encounter any issues, **immediately rollback**:

```bash
# Disable feature flag
export USE_DIRECT_ENTRY_TOPICS=false

# OR
sed -i 's/USE_DIRECT_ENTRY_TOPICS=true/USE_DIRECT_ENTRY_TOPICS=false/' .env
sudo systemctl restart morfeo-production

# Clear cache
RAILS_ENV=production bin/rails runner "Rails.cache.clear"

# Verify working
curl -I https://your-domain.com/topics/1
```

**This will restore Elasticsearch-based queries immediately!**

---

## 📋 Deployment Checklist

- [ ] Code deployed to production
- [ ] Feature flag set to `false` initially
- [ ] Test with flag OFF - existing behavior works
- [ ] Enable feature flag to `true`
- [ ] Clear Rails cache
- [ ] Test with flag ON - new associations work
- [ ] Monitor server resources (15-30 min)
- [ ] Run performance benchmark
- [ ] Verify < 250ms query times
- [ ] Check no SQL errors in logs
- [ ] Monitor for 24 hours
- [ ] If stable, proceed to Phase 4

---

## 📊 What Success Looks Like

✅ **Dashboard loads faster**
✅ **No Elasticsearch queries for Entry lookups**
✅ **MySQL handles load without issues**
✅ **No errors in production logs**
✅ **Server resources stable**
✅ **Users don't notice any change** (except speed improvement)

---

## 🎯 Next Steps (After 24hr Monitoring)

If Phase 3 is stable for 24 hours:

1. **Phase 4**: Apply same optimization to FacebookEntry and TwitterPost
2. **Phase 5**: Disable Elasticsearch indexing (save CPU)
3. **Phase 6**: Stop Elasticsearch service (save 33.6GB RAM!)

---

**Created**: November 1, 2025
**Status**: Ready for deployment
**Approved**: Code tested locally with ES stopped ✅


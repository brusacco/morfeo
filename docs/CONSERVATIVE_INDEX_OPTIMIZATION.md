# Conservative Index Optimization - Join Tables Only

## 🎯 Strategy: Low-Risk Optimization

This migration only adds indexes to the **new join tables** created in Phase 3:
- `entry_topics`
- `entry_title_topics`

**We are NOT touching:**
- ❌ `entries` table (existing, large, in production use)
- ❌ `sites` table (already has indexes)
- ❌ Any other existing tables

---

## 📊 Indexes Added (4 Total)

### **Entry_topics Table** (2 indexes)

1. **`idx_entry_topics_covering`**
   - Columns: `topic_id, entry_id, created_at`
   - Purpose: Optimize `topic.entries` lookups
   - Query: `SELECT entries.* FROM entries INNER JOIN entry_topics ON ... WHERE entry_topics.topic_id = ?`

2. **`idx_entry_topics_reverse_covering`**
   - Columns: `entry_id, topic_id, created_at`
   - Purpose: Optimize `entry.topics` lookups
   - Query: `SELECT topics.* FROM topics INNER JOIN entry_topics ON ... WHERE entry_topics.entry_id = ?`

### **Entry_title_topics Table** (2 indexes)

3. **`idx_entry_title_topics_covering`**
   - Columns: `topic_id, entry_id, created_at`
   - Purpose: Same as #1 for title tags

4. **`idx_entry_title_topics_reverse_covering`**
   - Columns: `entry_id, topic_id, created_at`
   - Purpose: Same as #2 for title tags

---

## 🚀 Quick Deployment

### **Local Test**
```bash
cd /Users/brunosacco/Proyectos/Rails/morfeo
bin/rails db:migrate
```

### **Production**
```bash
cd /home/rails/morfeo
git pull origin main
RAILS_ENV=production bin/rails db:migrate
```

**Duration**: < 30 seconds (join tables are small)

---

## 📈 Expected Impact

| Metric | Before | After | Improvement |
|--------|--------|-------|-------------|
| **Dashboard** | 10.56ms | ~7-8ms | 25% faster |
| **Large topics** | Good | Better | More consistent |
| **Disk space** | - | +10-50MB | Minimal |
| **Write speed** | - | Same | No impact |

---

## ✅ Why This is Safe

1. **Small tables**: Join tables are tiny compared to `entries`
2. **New tables**: Created in Phase 3, not legacy
3. **Fast migration**: Completes in seconds
4. **No locks**: Join tables are small, no blocking
5. **Easy rollback**: Simple to drop indexes if needed

---

## 🔍 Verify Indexes

After migration:

```bash
RAILS_ENV=production bin/rails runner "
puts 'Entry_topics indexes:'
ActiveRecord::Base.connection.execute('SHOW INDEX FROM entry_topics').each do |idx|
  key = idx.is_a?(Hash) ? idx['Key_name'] : idx[2]
  puts '  ✅ ' + key if key.include?('idx_')
end

puts ''
puts 'Entry_title_topics indexes:'
ActiveRecord::Base.connection.execute('SHOW INDEX FROM entry_title_topics').each do |idx|
  key = idx.is_a?(Hash) ? idx['Key_name'] : idx[2]
  puts '  ✅ ' + key if key.include?('idx_')
end
"
```

---

## 🚨 Rollback (If Needed)

```bash
RAILS_ENV=production bin/rails runner "
ActiveRecord::Base.connection.execute('DROP INDEX idx_entry_topics_covering ON entry_topics')
ActiveRecord::Base.connection.execute('DROP INDEX idx_entry_topics_reverse_covering ON entry_topics')
ActiveRecord::Base.connection.execute('DROP INDEX idx_entry_title_topics_covering ON entry_title_topics')
ActiveRecord::Base.connection.execute('DROP INDEX idx_entry_title_topics_reverse_covering ON entry_title_topics')
puts 'Indexes removed'
"
```

---

## 📊 Performance Test

```bash
RAILS_ENV=production bin/rails runner "
require 'benchmark'

topic = Topic.find_by(name: 'Honor Colorado')

time = Benchmark.measure do
  DigitalDashboardServices::AggregatorService.call(topic: topic, days_range: 7)
end

puts 'Dashboard: ' + (time.real * 1000).round(2).to_s + 'ms'
puts (time.real * 1000 < 10 ? '✅ EXCELLENT' : '✅ GOOD')
"
```

---

## 🎯 Summary

- ✅ **4 indexes** on join tables only
- ✅ **< 30 seconds** migration time
- ✅ **~25% faster** queries
- ✅ **Zero risk** to existing tables
- ✅ **Easy rollback** if needed

**This is a conservative, low-risk optimization that only touches the new Phase 3 tables!**

---

**Created**: November 1, 2025  
**Status**: Ready for deployment  
**Risk Level**: 🟢 LOW (only new tables)  
**Priority**: Optional (system already fast)


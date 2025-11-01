# Index Optimization Deployment Guide

## 📊 Performance Optimization Indexes

These indexes will further optimize the already-fast direct association queries, especially for large topics.

---

## 🎯 Expected Impact

| Scenario | Before Indexes | After Indexes | Improvement |
|----------|---------------|---------------|-------------|
| **Dashboard load** | 10.56ms | ~5-8ms | 25-50% faster |
| **Large topics (500+ entries)** | 265ms | ~100-150ms | 40-60% faster |
| **Site grouping** | Variable | Consistent | More stable |
| **Sentiment filtering** | Good | Excellent | Faster |

---

## 🚀 Deployment Commands

### **Local Testing (Development)**

```bash
# Run migration
bin/rails db:migrate

# Test performance
bin/rails runner "
require 'benchmark'

topic = Topic.find_by(name: 'Honor Colorado')
time = Benchmark.measure do
  result = DigitalDashboardServices::AggregatorService.call(topic: topic, days_range: 7)
  puts 'Entries: ' + result[:topic_data][:entries_count].to_s
end
puts 'Time: ' + (time.real * 1000).round(2).to_s + 'ms'
"
```

### **Production Deployment**

```bash
# SSH to production
ssh user@production-server
cd /home/rails/morfeo

# Pull changes
git pull origin main

# Run migration (this will take 1-3 minutes for large tables)
RAILS_ENV=production bin/rails db:migrate

# Monitor progress
tail -f log/production.log
```

---

## ⏱️ Migration Duration Estimate

Based on table sizes:

| Table | Estimated Time | Blocking? |
|-------|---------------|-----------|
| `entries` (1.2M rows) | 2-5 minutes | ⚠️ Yes (brief locks) |
| `entry_topics` (varies) | 30 seconds | ⚠️ Yes (brief locks) |
| `entry_title_topics` (varies) | 30 seconds | ⚠️ Yes (brief locks) |
| `sites` (small) | < 5 seconds | ⚠️ Yes (brief) |

**Total**: ~3-6 minutes

**Note**: MySQL 8.0 uses online DDL, so most locks are very brief. The site should remain available during migration.

---

## 🔍 Verify Indexes Created

After migration, verify indexes exist:

```bash
RAILS_ENV=production bin/rails runner "
puts '=' * 80
puts 'VERIFYING OPTIMIZATION INDEXES'
puts '=' * 80

# Check entries indexes
puts 'Entries indexes:'
ActiveRecord::Base.connection.execute('SHOW INDEX FROM entries WHERE Key_name LIKE \"idx_entries%\"').each do |idx|
  puts '  ✅ ' + (idx.is_a?(Hash) ? idx['Key_name'] : idx[2]).to_s
end

puts ''
puts 'Entry_topics indexes:'
ActiveRecord::Base.connection.execute('SHOW INDEX FROM entry_topics WHERE Key_name LIKE \"idx_entry_topics%\"').each do |idx|
  puts '  ✅ ' + (idx.is_a?(Hash) ? idx['Key_name'] : idx[2]).to_s
end

puts ''
puts 'Entry_title_topics indexes:'
ActiveRecord::Base.connection.execute('SHOW INDEX FROM entry_title_topics WHERE Key_name LIKE \"idx_entry_title%\"').each do |idx|
  puts '  ✅ ' + (idx.is_a?(Hash) ? idx['Key_name'] : idx[2]).to_s
end

puts ''
puts 'Sites indexes:'
ActiveRecord::Base.connection.execute('SHOW INDEX FROM sites WHERE Key_name = \"idx_sites_id_name\"').each do |idx|
  puts '  ✅ ' + (idx.is_a?(Hash) ? idx['Key_name'] : idx[2]).to_s
end

puts '=' * 80
"
```

---

## 📊 Performance Benchmark (After Indexes)

Run this after migration to measure improvement:

```bash
RAILS_ENV=production bin/rails runner "
require 'benchmark'

puts '=' * 80
puts 'POST-INDEX PERFORMANCE TEST'
puts '=' * 80

# Test all topics
Topic.limit(5).each do |topic|
  # Raw query performance
  raw_time = Benchmark.measure do
    topic.list_entries.to_a
  end
  
  # Dashboard performance
  dash_time = Benchmark.measure do
    DigitalDashboardServices::AggregatorService.call(topic: topic, days_range: 7)
  end
  
  puts topic.name
  puts '  Raw query: ' + (raw_time.real * 1000).round(2).to_s + 'ms'
  puts '  Dashboard: ' + (dash_time.real * 1000).round(2).to_s + 'ms'
  puts ''
end

puts '=' * 80
"
```

---

## 📋 Indexes Created

### **Entries Table** (4 new indexes)

1. `idx_entries_enabled_published_id`
   - Columns: `enabled, published_at, id`
   - Purpose: Optimize date range queries with enabled filter
   - Query: `entries.enabled.where(published_at: range)`

2. `idx_entries_published_enabled_site`
   - Columns: `published_at, enabled, site_id`
   - Purpose: Optimize joins with sites table
   - Query: `entries.where(published_at: range, enabled: true).joins(:site)`

3. `idx_entries_enabled_total_count`
   - Columns: `enabled, total_count, id`
   - Purpose: Optimize sorting by engagement
   - Query: `entries.enabled.order(total_count: :desc)`

4. `idx_entries_enabled_polarity`
   - Columns: `enabled, polarity, id`
   - Purpose: Optimize sentiment filtering
   - Query: `entries.enabled.where(polarity: [0, 1, 2])`

### **Entry_topics Table** (2 new indexes)

5. `idx_entry_topics_covering`
   - Columns: `topic_id, entry_id, created_at`
   - Purpose: Covering index for topic->entry lookups
   - Query: `entry_topics.where(topic_id: X).joins(:entry)`

6. `idx_entry_topics_reverse_covering`
   - Columns: `entry_id, topic_id, created_at`
   - Purpose: Covering index for entry->topics lookups
   - Query: `entry.topics`

### **Entry_title_topics Table** (2 new indexes)

7. `idx_entry_title_topics_covering`
   - Columns: `topic_id, entry_id, created_at`
   - Purpose: Same as #5 for title tags

8. `idx_entry_title_topics_reverse_covering`
   - Columns: `entry_id, topic_id, created_at`
   - Purpose: Same as #6 for title tags

### **Sites Table** (1 new index)

9. `idx_sites_id_name`
   - Columns: `id, name`
   - Purpose: Covering index for site grouping
   - Query: `entries.joins(:site).group('sites.name')`

---

## 🎯 Index Strategy Explained

### **Composite Indexes**
These indexes include multiple columns in strategic order:
1. **Filter columns first** (enabled, topic_id)
2. **Range columns second** (published_at)
3. **Sort/ID columns last** (total_count, id)

This order allows MySQL to:
- Use the index for filtering (`WHERE`)
- Use the same index for sorting (`ORDER BY`)
- Avoid table lookups (covering index)

### **Covering Indexes**
Indexes that include all columns needed for a query, so MySQL never needs to look at the actual table data. This is the fastest possible query execution.

---

## ⚠️ Important Notes

### **Disk Space**
- Each index adds ~5-10% of table size
- Total additional space: ~500MB - 1GB (estimated)
- Monitor with: `du -sh /var/lib/mysql/morfeo_production/`

### **INSERT/UPDATE Performance**
- Each index adds slight overhead to writes (~1-2ms per index)
- Since this is a read-heavy application (monitoring dashboards), this trade-off is acceptable
- Background jobs (scraping) might be 5-10% slower (still fine)

### **Index Maintenance**
- MySQL automatically maintains indexes
- Run `OPTIMIZE TABLE` monthly if needed:
  ```sql
  OPTIMIZE TABLE entries;
  OPTIMIZE TABLE entry_topics;
  OPTIMIZE TABLE entry_title_topics;
  ```

---

## 🚨 Rollback Plan

If indexes cause issues (unlikely), you can drop them:

```ruby
# Create a rollback migration
rails generate migration RemoveOptimizationIndexes

# Then edit it:
class RemoveOptimizationIndexes < ActiveRecord::Migration[7.0]
  def change
    remove_index :entries, name: 'idx_entries_enabled_published_id'
    remove_index :entries, name: 'idx_entries_published_enabled_site'
    remove_index :entries, name: 'idx_entries_enabled_total_count'
    remove_index :entries, name: 'idx_entries_enabled_polarity'
    remove_index :entry_topics, name: 'idx_entry_topics_covering'
    remove_index :entry_topics, name: 'idx_entry_topics_reverse_covering'
    remove_index :entry_title_topics, name: 'idx_entry_title_topics_covering'
    remove_index :entry_title_topics, name: 'idx_entry_title_topics_reverse_covering'
    remove_index :sites, name: 'idx_sites_id_name'
  end
end
```

---

## ✅ Success Criteria

After deploying indexes, you should see:

- ✅ Dashboard loads < 10ms (already achieved, should stay fast)
- ✅ Large topics (500+ entries) query in < 150ms
- ✅ No slow query warnings in MySQL logs
- ✅ Consistent, predictable performance
- ✅ No errors or crashes

---

## 📈 Next Steps

After indexes are deployed and stable:

1. **Monitor for 24 hours** - Watch performance metrics
2. **Analyze slow query log** - Identify any remaining bottlenecks
3. **Phase 4** - Apply same optimization to FacebookEntry and TwitterPost
4. **Phase 5** - Disable Elasticsearch indexing (save CPU)
5. **Phase 6** - Remove Elasticsearch entirely (already stopped!)

---

**Created**: November 1, 2025  
**Status**: Ready for deployment  
**Priority**: Medium (system is already fast, this makes it faster)  
**Risk**: Low (indexes are additive, easy to rollback)


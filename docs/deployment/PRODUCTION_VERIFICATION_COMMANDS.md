# Production Verification Commands

## 🚀 Quick Test Script

Run the comprehensive verification script:

```bash
RAILS_ENV=production bin/rails runner scripts/verify_production_indexes.rb
```

This will check:
1. ✅ All indexes exist
2. 📊 Table statistics
3. 🚀 Performance benchmarks (all topics)
4. 🔍 Query EXPLAIN analysis
5. 💾 Index size
6. ⚡ Cache performance
7. 📋 Summary & recommendations

---

## 📊 Individual Commands

### **1. Verify Indexes**
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

### **2. Quick Performance Test**
```bash
RAILS_ENV=production bin/rails runner "
require 'benchmark'

Topic.where(status: true).limit(5).each do |topic|
  time = Benchmark.measure do
    DigitalDashboardServices::AggregatorService.call(topic: topic, days_range: 7)
  end
  ms = (time.real * 1000).round(2)
  status = ms < 15 ? '🟢' : ms < 50 ? '🟡' : '🔴'
  puts topic.name.ljust(30) + ' | ' + ms.to_s.rjust(8) + 'ms | ' + status
end
"
```

---

### **3. Test Honor Colorado (Largest Topic)**
```bash
RAILS_ENV=production bin/rails runner "
require 'benchmark'

topic = Topic.find_by(name: 'Honor Colorado')
puts '=' * 80
puts 'Honor Colorado Performance Test'
puts '=' * 80

time = Benchmark.measure do
  result = DigitalDashboardServices::AggregatorService.call(topic: topic, days_range: 7)
  puts 'Entries: ' + result[:topic_data][:entries_count].to_s
  puts 'Interactions: ' + result[:topic_data][:total_interactions].to_s
end

ms = (time.real * 1000).round(2)
puts 'Dashboard load: ' + ms.to_s + 'ms'
puts ''
puts ms < 15 ? '✅ EXCELLENT' : ms < 50 ? '✅ GOOD' : '⚠️ NEEDS REVIEW'
puts '=' * 80
"
```

---

### **4. Check Index Sizes**
```bash
RAILS_ENV=production bin/rails runner "
['entry_topics', 'entry_title_topics'].each do |table|
  result = ActiveRecord::Base.connection.execute(\"
    SELECT 
      ROUND((index_length / 1024 / 1024), 2) AS 'Index Size (MB)'
    FROM information_schema.TABLES 
    WHERE table_schema = DATABASE()
    AND table_name = '#{table}'
  \").first
  
  size = result.is_a?(Hash) ? result['Index Size (MB)'] : result[0]
  puts table + ': ' + size.to_s + ' MB'
end
"
```

---

### **5. Query EXPLAIN (See what indexes are used)**
```bash
RAILS_ENV=production bin/rails runner "
topic = Topic.first
query = topic.entries.enabled.where(published_at: 7.days.ago..).joins(:site).to_sql
puts 'Query:'
puts query
puts ''
puts 'EXPLAIN:'
ActiveRecord::Base.connection.execute('EXPLAIN ' + query).each do |row|
  if row.is_a?(Hash)
    puts '  Key: ' + row['key'].to_s + ' | Rows: ' + row['rows'].to_s
  end
end
"
```

---

### **6. Count Associations**
```bash
RAILS_ENV=production bin/rails runner "
puts 'EntryTopic associations: ' + EntryTopic.count.to_s
puts 'EntryTitleTopic associations: ' + EntryTitleTopic.count.to_s
puts 'Total Topics: ' + Topic.count.to_s
puts 'Total Entries: ' + Entry.count.to_s
"
```

---

### **7. Test Cache Performance**
```bash
RAILS_ENV=production bin/rails runner "
require 'benchmark'

topic = Topic.first

# Clear cache
Rails.cache.delete('topic_' + topic.id.to_s + '_list_entries_v2')

# First call (no cache)
time1 = Benchmark.measure { topic.list_entries.to_a }

# Second call (with cache)
time2 = Benchmark.measure { topic.list_entries.to_a }

puts 'Without cache: ' + (time1.real * 1000).round(2).to_s + 'ms'
puts 'With cache: ' + (time2.real * 1000).round(2).to_s + 'ms'
puts 'Speedup: ' + (time1.real / time2.real).round(1).to_s + 'x'
"
```

---

## 🎯 Expected Results

| Metric | Target | Status |
|--------|--------|--------|
| **Dashboard load** | < 15ms | 🟢 Excellent |
| **Large topics (500+ entries)** | < 50ms | 🟡 Good |
| **Very large topics (1000+)** | < 100ms | 🟠 Acceptable |
| **Index size** | < 100MB | ✅ Minimal impact |
| **All indexes present** | 4 indexes | ✅ Verified |

---

## 📋 Troubleshooting

### **If performance is slower than expected:**

1. **Check if indexes are being used:**
```bash
RAILS_ENV=production bin/rails runner "
topic = Topic.first
query = topic.entries.enabled.where(published_at: 7.days.ago..).to_sql
puts ActiveRecord::Base.connection.execute('EXPLAIN ' + query).first.inspect
"
```

2. **Clear all caches:**
```bash
RAILS_ENV=production bin/rails runner "Rails.cache.clear; puts 'Cache cleared'"
sudo systemctl restart morfeo-production
```

3. **Check MySQL slow query log:**
```bash
tail -f /var/log/mysql/slow-query.log
```

4. **Analyze tables:**
```bash
mysql -u root -p -e "
USE morfeo_production;
ANALYZE TABLE entry_topics;
ANALYZE TABLE entry_title_topics;
"
```

---

## ✅ Success Checklist

- [ ] All 4 indexes present
- [ ] Honor Colorado < 15ms
- [ ] All topics < 50ms (acceptable)
- [ ] No errors in logs
- [ ] Indexes being used (check EXPLAIN)
- [ ] Cache working correctly

---

**Run the main script for a complete report:**
```bash
RAILS_ENV=production bin/rails runner scripts/verify_production_indexes.rb > /tmp/index_report.txt
cat /tmp/index_report.txt
```



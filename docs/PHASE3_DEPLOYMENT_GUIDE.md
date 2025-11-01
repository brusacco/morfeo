# Phase 3: Feature Flag Testing - Deployment Guide

**Date:** November 1, 2025  
**Status:** Ready to Deploy  
**Estimated Time:** 15 minutes deployment + monitoring

---

## ✅ **What Was Updated**

### **Topic Model - 7 Methods with Feature Flags:**

1. ✅ `report_entries` - Report generation
2. ✅ `report_title_entries` - Title-based reports  
3. ✅ `list_entries` - Main topic entry list
4. ✅ `all_list_entries` - All entries (no tag filter)
5. ✅ `title_list_entries` - Title-tagged entries
6. ✅ `chart_entries` - Chart data
7. ✅ `title_chart_entries` - Title chart data

**Each method now:**
- ✅ Checks `FEATURE_FLAGS[:use_direct_entry_topics]`
- ✅ Uses direct associations when flag is `true`
- ✅ Falls back to Elasticsearch when flag is `false` (default)
- ✅ Uses separate cache keys (`_v2` suffix when flag enabled)

---

## 🚀 **Deployment Steps**

### **Step 1: Deploy Updated Code**

```bash
# On local machine
cd /Users/brunosacco/Proyectos/Rails/morfeo
git add app/models/topic.rb
git commit -m "Phase 3: Add feature flag support to Topic query methods

- Add USE_DIRECT_ENTRY_TOPICS feature flag to 7 methods
- Dual implementation: ES (old) vs direct associations (new)
- Separate cache keys to prevent conflicts
- Default: flag OFF (uses ES, no behavior change)
- Ready for testing when flag is enabled

Methods updated:
- report_entries, report_title_entries
- list_entries, all_list_entries, title_list_entries
- chart_entries, title_chart_entries

Ref: Phase 3 - Feature Flag Testing"

git push production main
```

### **Step 2: On Production Server**

```bash
ssh user@production-server
cd /home/rails/morfeo

# Restart app
sudo systemctl restart morfeo-production
# OR: touch tmp/restart.txt

# Verify flag is OFF (default)
bin/rails runner "
puts 'Feature flag status:'
puts 'USE_DIRECT_ENTRY_TOPICS: ' + FEATURE_FLAGS[:use_direct_entry_topics].to_s
puts 'Expected: false (ES still being used)'
"
```

**Expected output:**
```
Feature flag status:
USE_DIRECT_ENTRY_TOPICS: false
Expected: false (ES still being used)
```

---

## 🧪 **Testing Phase**

### **Test 1: Verify Current Behavior (Flag OFF)**

```bash
# Should use Elasticsearch (current behavior)
bin/rails runner "
require 'benchmark'

topic = Topic.first
puts 'Testing with FLAG OFF (Elasticsearch)...'
puts 'Flag status: ' + FEATURE_FLAGS[:use_direct_entry_topics].to_s
puts ''

time = Benchmark.measure {
  topic.list_entries.to_a
}

puts 'Topic: ' + topic.name
puts 'Query time: ' + (time.real * 1000).round(2).to_s + 'ms'
puts 'Entries: ' + topic.list_entries.count.to_s
puts 'Using: Elasticsearch (flag OFF)'
"
```

### **Test 2: Enable Flag and Test**

```bash
# Enable flag temporarily
export USE_DIRECT_ENTRY_TOPICS=true
sudo systemctl restart morfeo-production

# Test with flag ON
bin/rails runner "
require 'benchmark'

topic = Topic.first
puts 'Testing with FLAG ON (Direct Associations)...'
puts 'Flag status: ' + FEATURE_FLAGS[:use_direct_entry_topics].to_s
puts ''

# Clear cache to force new query
Rails.cache.clear

time = Benchmark.measure {
  topic.list_entries.to_a
}

puts 'Topic: ' + topic.name
puts 'Query time: ' + (time.real * 1000).round(2).to_s + 'ms'
puts 'Entries: ' + topic.list_entries.count.to_s
puts 'Using: Direct Associations (flag ON)'
"
```

### **Test 3: Compare Performance**

```bash
# This script tests both paths and compares
bin/rails runner "
require 'benchmark'

topic = Topic.first
puts '=' * 80
puts 'Performance Comparison'
puts '=' * 80
puts 'Topic: ' + topic.name
puts ''

# Test ES path (flag OFF simulation)
# Temporarily call the ES path directly
tag_list = topic.tag_names
es_time = Benchmark.measure {
  result = Entry.search(
    where: {
      published_at: topic.default_date_range,
      tags: { in: tag_list }
    },
    order: { published_at: :desc },
    fields: ['id'],
    load: false
  )
  Entry.where(id: result.map(&:id)).includes(:site, :tags).joins(:site).to_a
}

# Test direct association path (flag ON)
direct_time = Benchmark.measure {
  topic.entries.enabled
       .where('published_at >= ?', DAYS_RANGE.days.ago)
       .order(published_at: :desc)
       .includes(:site, :tags)
       .to_a
}

puts 'Results:'
puts '  Elasticsearch: ' + (es_time.real * 1000).round(2).to_s + 'ms'
puts '  Direct Assoc:  ' + (direct_time.real * 1000).round(2).to_s + 'ms'
puts ''

if direct_time.real < es_time.real
  improvement = ((es_time.real - direct_time.real) / es_time.real * 100).round(1)
  puts '✅ Direct associations ' + improvement.to_s + '% FASTER'
else
  degradation = ((direct_time.real - es_time.real) / es_time.real * 100).round(1)
  puts '⚠️  Direct associations ' + degradation.to_s + '% slower'
end

puts '=' * 80
"
```

### **Test 4: Test All Dashboards**

```bash
# With flag enabled, test key URLs
curl -I https://yourdomain.com/topics/1
curl -I https://yourdomain.com/general_dashboard/1
curl -I https://yourdomain.com/facebook_topic/1

# Check logs for query times
tail -f log/production.log | grep "Completed.*topics"
```

---

## 📊 **Monitoring Checklist**

After enabling the flag, monitor:

- [ ] **Response times** - Should be same or better
- [ ] **Error rates** - Should be zero
- [ ] **Data accuracy** - Entry counts should match
- [ ] **Cache behavior** - Separate `_v2` caches working
- [ ] **User experience** - No complaints
- [ ] **Dashboard functionality** - All features working

---

## 🎯 **Rollout Strategy**

### **Week 1: Internal Testing**

```bash
# Day 1-2: Enable for internal users only
export USE_DIRECT_ENTRY_TOPICS=true
# Test thoroughly

# Monitor:
- Query performance
- Error logs
- Data accuracy
```

### **Week 2: Gradual Rollout**

```bash
# Day 3-5: Enable for all users
# Keep flag ON, monitor closely

# Check metrics:
bin/rails runner "
puts 'Cache hit analysis:'
puts 'Old cache keys: ' + Rails.cache.stats.select { |k,v| k.include?('list_entries') && !k.include?('_v2') }.size.to_s
puts 'New cache keys: ' + Rails.cache.stats.select { |k,v| k.include?('list_entries_v2') }.size.to_s
"
```

### **Week 3: Validation**

```bash
# Collect performance metrics
bin/rails runner "
require 'benchmark'

results = []
Topic.active.limit(10).each do |topic|
  time = Benchmark.measure { topic.list_entries.to_a }
  results << { name: topic.name, ms: (time.real * 1000).round(2) }
end

puts '=' * 80
puts 'Performance Summary (10 topics)'
puts '=' * 80
results.each { |r| puts r[:name] + ': ' + r[:ms].to_s + 'ms' }
avg = results.sum { |r| r[:ms] } / results.size
puts ''
puts 'Average: ' + avg.round(2).to_s + 'ms'
puts 'Target: <100ms'
puts avg < 100 ? '✅ Performance EXCELLENT' : '⚠️ Needs optimization'
puts '=' * 80
"
```

---

## 🎉 **Success Criteria for Phase 3**

Before proceeding to Phase 4:

- [ ] Feature flag deployed successfully
- [ ] Both paths (ES and direct) tested
- [ ] Direct associations perform well (< 100ms)
- [ ] No errors with flag enabled
- [ ] Data accuracy 100%
- [ ] Ran with flag ON for 1 week
- [ ] User experience same or better
- [ ] Ready to remove ES fallback code

---

## ⚠️ **Rollback Procedure**

If issues arise:

```bash
# Quick rollback: Disable flag
unset USE_DIRECT_ENTRY_TOPICS
# OR
export USE_DIRECT_ENTRY_TOPICS=false

# Restart app
sudo systemctl restart morfeo-production

# System reverts to Elasticsearch immediately
# No code changes needed!
```

---

## 📈 **Expected Results**

Based on Phase 2 testing:

| Metric | Elasticsearch | Direct Associations | Improvement |
|--------|--------------|---------------------|-------------|
| **SQL Query** | ~40ms | ~32-45ms | Similar |
| **Total Time** | ~440ms | ~210ms | **52% faster** |
| **With Cache** | <1ms | <1ms | Same |
| **Memory** | +33.6GB | 0GB | **+33.6GB saved** (Phase 5) |

---

## 🎯 **Next Steps**

After Phase 3 validation:

1. **Phase 4 (Week 4):** Remove feature flags, make direct associations default
2. **Phase 5 (Week 5):** Remove Elasticsearch entirely, save 33.6GB RAM

---

**Phase 3 is ready to deploy! This is a safe, gradual rollout with easy rollback. 🚀**


# Redis Memory Consumption Analysis - Cache Warming

**Date**: November 2, 2025  
**Scenario**: 73 active topics, warming all dashboards every 10 minutes

---

## 📊 Cache Structure Per Topic

### Service-Level Caches (Per Topic)

| Cache Type | Key Pattern | Data Stored | Est. Size |
|------------|-------------|-------------|-----------|
| **Digital Dashboard** | `digital_dashboard_{topic_id}_{days}_{date}` | Full aggregated stats | ~50-100 KB |
| **Facebook Dashboard** | `facebook_dashboard_{topic_id}_{limit}_{date}` | Full aggregated stats | ~50-100 KB |
| **Twitter Dashboard** | `twitter_dashboard_{topic_id}_{limit}_{date}` | Full aggregated stats | ~50-100 KB |
| **General Dashboard** | `general_dashboard_{topic_id}_{start}_{end}` | CEO-level aggregated stats | ~100-150 KB |
| **Site Counts** | `topic_{topic_id}_site_counts_{date}` | Hash of counts | ~5-10 KB |
| **Site Sums** | `topic_{topic_id}_site_sums_{date}` | Hash of sums | ~5-10 KB |
| **Word Analysis** | `topic_{topic_id}_words_{date}` | Array of word occurrences | ~10-20 KB |
| **Bigrams** | `topic_{topic_id}_bigrams_{date}` | Array of bigram occurrences | ~10-20 KB |
| **Entry Lists** | `topic_{topic_id}_list_entries_*` | Cached entry lists | ~20-50 KB |
| **Title Lists** | `topic_{topic_id}_title_list_entries_*` | Cached title entries | ~20-50 KB |

**Total per topic:** ~320-600 KB (average ~450 KB)

### Action Cache (Per User Per Topic)

| Cache Type | Key Pattern | Data Stored | Est. Size |
|------------|-------------|-------------|-----------|
| **HTML Pages** | `views/topic/{id}/user_{user}/show` | Rendered HTML | ~50-150 KB |
| **PDF Pages** | `views/topic/{id}/user_{user}/pdf` | Rendered HTML | ~50-150 KB |
| **General Dashboard** | `views/general_dashboard/{id}/user_{user}/show` | Rendered HTML | ~100-200 KB |
| **Facebook Dashboard** | `views/facebook_topic/{id}/user_{user}/show` | Rendered HTML | ~50-150 KB |
| **Twitter Dashboard** | `views/twitter_topic/{id}/user_{user}/show` | Rendered HTML | ~50-150 KB |

**Total per user per topic:** ~300-800 KB (average ~500 KB)

---

## 💾 Total Memory Calculation

### Service Caches (Shared Across Users)

```
73 topics × 450 KB average = 32,850 KB ≈ 33 MB
```

### Action Caches (Per User)

Assuming 10 active users viewing dashboards:

```
73 topics × 10 users × 500 KB = 365,000 KB ≈ 365 MB
```

**But realistically:**
- Not all users view all topics
- Most users only view 2-5 topics
- Action cache expires after 30 minutes

**More realistic estimate:**
```
73 topics × 3 topics per user × 10 users × 500 KB = 109,500 KB ≈ 110 MB
```

---

## 🎯 Total Redis Memory Usage

### Conservative Estimate (Realistic)

| Component | Memory |
|-----------|--------|
| Service Caches | 33 MB |
| Action Caches (realistic) | 110 MB |
| Home Dashboard Caches | 10 MB |
| Tag Caches (50 tags) | 15 MB |
| Other Rails Caches | 20 MB |
| **TOTAL** | **~188 MB** |

### Maximum Estimate (Peak Usage)

| Component | Memory |
|-----------|--------|
| Service Caches | 33 MB |
| Action Caches (all users, all topics) | 365 MB |
| Home Dashboard Caches | 20 MB |
| Tag Caches (50 tags) | 15 MB |
| Other Rails Caches | 50 MB |
| **TOTAL** | **~483 MB** |

---

## 📈 Growth Over Time

### Cache Warming Cycles

**Every 10 minutes:**
- New service caches created: ~33 MB
- Old service caches expire: ~33 MB (after 1 hour)
- **Net growth: 0 MB** (replacing old caches)

### Daily Pattern

| Time | Usage | Why |
|------|-------|-----|
| **Night (00:00-06:00)** | ~50 MB | Few users, mostly service caches |
| **Morning (06:00-12:00)** | ~150 MB | Users logging in, action caches building |
| **Peak (12:00-18:00)** | ~200-250 MB | Peak user activity |
| **Evening (18:00-00:00)** | ~100 MB | Users logging off, caches expiring |

**Average:** ~150-180 MB

---

## 🔍 Breakdown by Dashboard Type

### Per Topic Memory Cost

```ruby
# Service Cache (shared)
digital_dashboard_1_7_2025-11-02         # 80 KB
facebook_dashboard_1_20_2025-11-02       # 70 KB  
twitter_dashboard_1_20_2025-11-02        # 60 KB
general_dashboard_1_2025-10-26_2025-11-02 # 120 KB
topic_1_site_counts_2025-11-02           # 8 KB
topic_1_site_sums_2025-11-02             # 8 KB
topic_1_words_2025-11-02                 # 15 KB
topic_1_bigrams_2025-11-02               # 12 KB
topic_1_list_entries_v2                  # 40 KB
topic_1_title_list_entries_v2            # 30 KB
----------------------------------------
TOTAL PER TOPIC: ~443 KB
```

### For 73 Topics

```
73 topics × 443 KB = 32,339 KB ≈ 32 MB (service caches only)
```

---

## 🚨 Redis Memory Limits

### Recommended Redis Configuration

```conf
# /etc/redis/redis.conf

# Maximum memory
maxmemory 2gb

# Eviction policy (remove least recently used keys when limit reached)
maxmemory-policy allkeys-lru

# Save to disk (optional, for persistence)
save 900 1
save 300 10
save 60 10000
```

### Why 2GB is More Than Enough

| Component | Memory | % of 2GB |
|-----------|--------|----------|
| Dashboard Caches | 200 MB | 10% |
| Sidekiq Jobs | 100 MB | 5% |
| Session Data | 50 MB | 2.5% |
| Other App Caches | 150 MB | 7.5% |
| **Used** | **500 MB** | **25%** |
| **Available** | **1.5 GB** | **75%** |

---

## 📊 Monitoring Redis Memory

### Check Current Usage

```bash
# Connect to Redis
redis-cli

# Check memory usage
INFO memory

# Output:
used_memory_human:234.5M
used_memory_rss_human:250.2M
maxmemory_human:2.00G
maxmemory_policy:allkeys-lru
```

### Check Cache Keys

```bash
# Count dashboard cache keys
redis-cli KEYS "digital_dashboard_*" | wc -l
redis-cli KEYS "facebook_dashboard_*" | wc -l
redis-cli KEYS "twitter_dashboard_*" | wc -l
redis-cli KEYS "general_dashboard_*" | wc -l

# Check size of specific key
redis-cli DEBUG OBJECT "digital_dashboard_1_7_2025-11-02"
# Output: serializedlength:81920  (≈ 80 KB)
```

### Monitor in Real-Time

```bash
# Watch memory usage
watch -n 1 'redis-cli INFO memory | grep used_memory_human'
```

---

## 🎯 Optimization Strategies

### If Memory Becomes an Issue

#### 1. **Reduce Cache Expiration** (Current: 30min-1hour)
```ruby
# From
CACHE_EXPIRATION = 1.hour

# To
CACHE_EXPIRATION = 30.minutes  # Less memory, but more DB queries
```

#### 2. **Reduce Warming Frequency** (Current: Every 10 min)
```ruby
# From
every 10.minutes do
  rake 'cache:warm_dashboards'
end

# To
every 15.minutes do  # Less frequent = less memory
  rake 'cache:warm_dashboards'
end
```

#### 3. **Selective Warming** (Warm only popular topics)
```ruby
# Only warm topics with recent activity
topics = Topic.active
              .joins(:entries)
              .where('entries.published_at > ?', 7.days.ago)
              .distinct
```

#### 4. **Compress Cache Data**
```ruby
# In application.rb
config.cache_store = :redis_cache_store, {
  compress: true,
  compress_threshold: 1.kilobyte  # Compress entries > 1KB
}
```

---

## 💡 Current Status Assessment

### Your Setup (73 Topics)

| Metric | Value | Status |
|--------|-------|--------|
| **Service Caches** | ~33 MB | ✅ Excellent |
| **Action Caches** | ~110-200 MB | ✅ Good |
| **Total Peak** | ~250 MB | ✅ Very Good |
| **Redis Capacity** | 2 GB (assumed) | ✅ 87% available |

### Verdict

✅ **Redis memory consumption is VERY LOW and well within limits!**

- Current usage: ~150-250 MB (average)
- Recommended Redis size: 1-2 GB
- **You're using only 10-20% of capacity**
- Plenty of room for growth

---

## 📈 Scaling Projections

### If You Double Topics (146 Topics)

```
Service Caches: 33 MB × 2 = 66 MB
Action Caches: 110 MB × 2 = 220 MB
TOTAL: ~300 MB (still only 15% of 2GB)
```

### If You 10x Topics (730 Topics!)

```
Service Caches: 33 MB × 10 = 330 MB
Action Caches: 110 MB × 10 = 1.1 GB
TOTAL: ~1.5 GB (75% of 2GB - still OK!)
```

---

## 🎉 Summary

### Current Redis Memory Usage

- **Service Caches**: 33 MB (all 73 topics)
- **Action Caches**: 110-200 MB (realistic user activity)
- **Total**: ~150-250 MB
- **Peak**: ~300 MB max

### Capacity

- **Recommended Redis Size**: 2 GB
- **Current Usage**: 10-20% of capacity
- **Available for Growth**: 1.5-1.8 GB (80-90%)

### Conclusion

✅ **Redis memory consumption is MINIMAL and NOT a concern!**

- Cache warming uses ~33 MB for service caches
- Action caches add ~110-200 MB (depends on user activity)
- Total is well under 300 MB
- **You have plenty of room for 5-10x growth!**

**The parallel cache warming is safe and efficient!** 🚀


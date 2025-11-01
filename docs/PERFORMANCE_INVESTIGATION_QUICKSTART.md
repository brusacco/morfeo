# Morfeo Performance Investigation - Quick Start Guide

**Date:** November 1, 2025  
**Status:** 🔬 Diagnostic Phase  
**Goal:** Identify and fix the real performance bottleneck

---

## 📊 Current Server State

```
MySQL:          69.5GB RAM (27.6%)
Elasticsearch:  33.6GB RAM (13.3%)
Total:         103.1GB RAM
```

**Question:** Is Elasticsearch helping or hiding a problem?

---

## 🎯 Investigation Steps

### Step 1: Diagnose Tagging Performance (15 minutes) ⚡

```bash
# This will test if acts_as_taggable_on is the bottleneck
rails runner scripts/diagnose_tagging_performance.rb
```

**What this reveals:**
- Baseline query time (no tagging)
- acts_as_taggable_on overhead
- Alternative approaches
- Fastest solution for your data

### Step 2: Verify Database Indexes (5 minutes)

```bash
# Check if you have optimal indexes
rails runner scripts/verify_mysql_indexes.rb
```

**What this reveals:**
- Missing critical indexes
- Composite index opportunities
- Data volume insights

### Step 3: Benchmark ES vs MySQL (10 minutes)

```bash
# Compare Elasticsearch vs pure MySQL performance
rails runner scripts/benchmark_es_vs_mysql.rb
```

**What this reveals:**
- Real-world query times
- Memory usage comparison
- Caching impact
- Clear recommendation

---

## 🚦 Decision Tree

Based on diagnostic results:

### Scenario A: Tagging is Slow (>100ms overhead)

**This is likely your situation.**

```
Problem: acts_as_taggable_on JOINs are expensive
Symptom: Elasticsearch "fixes" it by avoiding JOINs
Cost: 33.6GB RAM for a band-aid solution

Solution:
1. Implement Entry-Topic direct associations (4 hours)
2. Remove Elasticsearch (2 hours)

Result:
✅ 10-30ms queries (faster than ES!)
✅ Save 33.6GB RAM
✅ Cleaner code
```

**Read:** `docs/ACTS_AS_TAGGABLE_OPTIMIZATION.md`  
**Implement:** Solution 4 (Entry-Topic association)

---

### Scenario B: Tagging is Medium (50-100ms overhead)

**Quick wins first.**

```
Problem: Tagging has some overhead but not critical
Solution: Quick optimizations

Quick Wins:
1. Add composite indexes (30 min)
2. Use tag IDs instead of names (1 hour)
3. Test if good enough

If still slow:
→ Go to Scenario A
```

**Read:** `docs/ACTS_AS_TAGGABLE_OPTIMIZATION.md`  
**Implement:** Solutions 2 & 3

---

### Scenario C: Tagging is Fast (<50ms overhead)

**ES is just overhead.**

```
Problem: Elasticsearch not providing value
Tagging: Already fast
ES Cost: 33.6GB RAM for minimal benefit

Solution:
1. Remove Elasticsearch (4 hours)
2. Use pure MySQL queries
3. Save 33.6GB RAM

Result:
✅ 20-30ms queries (same or better)
✅ Save 33.6GB RAM
✅ Simpler stack
```

**Read:** `docs/ELASTICSEARCH_MIGRATION_ANALYSIS.md`  
**Follow:** Original ES removal plan

---

## 📋 Quick Implementation Checklist

### If Tagging is the Issue (Most Likely)

#### Phase 1: Quick Wins (2 hours)
- [ ] Run diagnostics
- [ ] Add composite indexes
- [ ] Use tag ID optimization
- [ ] Measure improvement

#### Phase 2: Direct Associations (4 hours)
- [ ] Create entry_topics table
- [ ] Create facebook_entry_topics table
- [ ] Create twitter_post_topics table
- [ ] Add model associations
- [ ] Backfill existing data
- [ ] Update Topic query methods
- [ ] Test all dashboards

#### Phase 3: Remove Elasticsearch (2 hours)
- [ ] Remove searchkick from Entry model
- [ ] Remove from Gemfile
- [ ] Deploy to staging
- [ ] Monitor for 24 hours
- [ ] Deploy to production
- [ ] Stop ES service
- [ ] Free 33.6GB RAM 🎉

---

### If Elasticsearch is the Only Issue (Less Likely)

#### Phase 1: Replace ES Queries (3 hours)
- [ ] Replace Topic#list_entries
- [ ] Replace Topic#report_entries
- [ ] Replace Topic search methods
- [ ] Replace Tag search methods
- [ ] Add Tag.search_by_name
- [ ] Test all dashboards

#### Phase 2: Remove ES (1 hour)
- [ ] Remove searchkick
- [ ] Remove from Gemfile
- [ ] Deploy
- [ ] Stop ES service

---

## 🎓 Key Insights

### Why This Matters

**Current state:**
```ruby
# Step 1: Query ES (avoids tagging JOIN)
es_ids = Entry.search(where: {...}).map(&:id)

# Step 2: Query MySQL with IDs
Entry.where(id: es_ids)

# Cost: 33.6GB RAM
```

**Optimized state:**
```ruby
# Single query with direct association
Entry.joins(:entry_topics)
     .where(entry_topics: { topic_id: topic.id })
     .where(published_at: date_range)

# Cost: 0GB RAM
# Speed: Faster than ES!
```

### The Pattern

1. **Polymorphic JOINs are expensive** (`acts_as_taggable_on`)
2. **Elasticsearch avoids JOINs** (but costs RAM)
3. **Direct associations avoid JOINs too** (and cost nothing!)

---

## 📊 Expected Performance Improvements

| Approach | Query Time | RAM Usage | Complexity |
|----------|-----------|-----------|------------|
| **Current (ES + tagging)** | 35-50ms | +33.6GB | High |
| **MySQL + slow tagging** | 100-200ms | 0GB | Medium |
| **MySQL + optimized tagging** | 20-50ms | 0GB | Medium |
| **MySQL + direct associations** | 10-30ms | 0GB | Low |

---

## 🚀 Recommended Path Forward

### Today (30 minutes)
1. Run all three diagnostic scripts
2. Review results
3. Identify bottleneck
4. Choose optimization path

### This Week (4-8 hours)
1. Implement chosen solution
2. Test in staging
3. Deploy to production
4. Monitor performance

### Next Week
1. Remove Elasticsearch (if applicable)
2. Free 33.6GB RAM
3. Celebrate simpler stack 🎉

---

## 📁 Documentation Reference

- **Tagging optimization:** `docs/ACTS_AS_TAGGABLE_OPTIMIZATION.md`
- **ES removal:** `docs/ELASTICSEARCH_MIGRATION_ANALYSIS.md`
- **Diagnostic scripts:** `scripts/diagnose_tagging_performance.rb`
- **Benchmark tools:** `scripts/benchmark_es_vs_mysql.rb`
- **Index verification:** `scripts/verify_mysql_indexes.rb`

---

## 💡 Pro Tips

1. **Run diagnostics in production** (if safe) for real data
2. **Peak hours matter** - test during high traffic
3. **Cache hit rate** - 90% of queries should be cached anyway
4. **Monitor after changes** - watch for regressions
5. **Keep ES running** for 1 week after migration (safety buffer)

---

## ❓ Common Questions

**Q: Will this break anything?**  
A: No, all changes are additive first, then we remove ES.

**Q: How long will migration take?**  
A: 4-8 hours total, can be done in phases.

**Q: What if performance gets worse?**  
A: Keep ES running initially, easy to rollback.

**Q: Do we need downtime?**  
A: No, zero-downtime migration possible.

**Q: What about our 2M entries?**  
A: This is exactly the scale where these optimizations shine.

---

## 🎯 Success Criteria

After optimization, you should see:

- ✅ Query times: 10-50ms (cold cache)
- ✅ Query times: <1ms (warm cache, 90% of requests)
- ✅ RAM saved: 33.6GB
- ✅ System complexity: Reduced
- ✅ Maintenance burden: Lower
- ✅ Code clarity: Improved (direct associations)

---

**Ready to start?** Run the diagnostics and let's identify the real bottleneck!

```bash
# Run all diagnostics
rails runner scripts/diagnose_tagging_performance.rb
rails runner scripts/verify_mysql_indexes.rb
rails runner scripts/benchmark_es_vs_mysql.rb
```


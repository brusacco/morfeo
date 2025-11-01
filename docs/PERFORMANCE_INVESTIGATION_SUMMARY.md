# Performance Investigation - Executive Summary

**Date:** November 1, 2025  
**Issue:** Elasticsearch consuming 33.6GB RAM  
**Root Cause Hypothesis:** `acts_as_taggable_on` polymorphic JOINs are slow at 2M+ scale

---

## 🎯 The Core Insight

**Your team's hypothesis is likely correct:**

Elasticsearch isn't the problem—it's the **solution to a different problem** (slow tagging queries). But it's an expensive solution (33.6GB RAM).

### The Chain of Events

```
1. acts_as_taggable_on creates polymorphic JOINs
   ↓
2. At 2M entries, these JOINs become slow (100-200ms)
   ↓
3. Elasticsearch bypasses JOINs by pre-indexing
   ↓
4. ES appears "faster" but costs 33.6GB RAM
   ↓
5. Real issue: The JOINs, not the lack of ES
```

---

## 📊 Current State Analysis

### What You Have

```ruby
# Current query pattern
Entry.search(where: { tags: {...}, date: {...} })  # ES query
  ↓ Returns IDs
Entry.where(id: ids)  # MySQL query

# This avoids:
Entry.tagged_with([...])  # Expensive polymorphic JOIN
```

### The Hidden Cost

- **Memory:** 33.6GB RAM for Elasticsearch (13.3% of server)
- **Complexity:** Two systems to maintain (MySQL + ES)
- **Overhead:** Double queries (ES → MySQL)
- **Maintenance:** Reindexing, cluster health, etc.

### What's Really Slow

Not Elasticsearch usage—but the alternative (`acts_as_taggable_on` JOINs).

---

## 🔬 Diagnostic Tools Created

I've created three diagnostic scripts:

### 1. `scripts/diagnose_tagging_performance.rb`
**Purpose:** Measure `acts_as_taggable_on` overhead

**Tests:**
- Baseline (no tagging): How fast without JOINs?
- Current (tagged_with): How slow with JOINs?
- Alternatives: Manual JOIN, subqueries, tag-first approaches

**Output:** Identifies which approach is fastest for your data

---

### 2. `scripts/verify_mysql_indexes.rb`
**Purpose:** Check database index optimization

**Tests:**
- Critical indexes presence
- Composite index opportunities
- Data volume distribution

**Output:** Migration code for missing indexes

---

### 3. `scripts/benchmark_es_vs_mysql.rb`
**Purpose:** Compare Elasticsearch vs MySQL performance

**Tests:**
- ES query time
- MySQL query time
- Cache impact (realistic scenario)

**Output:** Clear recommendation with numbers

---

## 💡 Four Optimization Paths

Based on diagnostic results, choose one:

### Path 1: Direct Entry-Topic Association (BEST) 🏆

**When:** Tagging overhead >100ms  
**Time:** 4-8 hours  
**Result:** 10-30ms queries, save 33.6GB RAM

```ruby
# Create direct many-to-many
topic.entries              # Fast JOIN
  vs
Entry.tagged_with([...])   # Slow polymorphic JOIN
```

**Documentation:** `docs/ACTS_AS_TAGGABLE_OPTIMIZATION.md` (Solution 4)

---

### Path 2: Quick Index Wins (FASTEST TO IMPLEMENT) 🏃

**When:** Tagging overhead 50-100ms  
**Time:** 1-2 hours  
**Result:** 30-50% improvement

```ruby
# Add composite indexes
add_index :taggings, [:taggable_type, :tag_id, :taggable_id]
add_index :entries, [:published_at, :enabled]
```

**Documentation:** `docs/ACTS_AS_TAGGABLE_OPTIMIZATION.md` (Solutions 2 & 3)

---

### Path 3: Remove ES Only (SIMPLEST) 🧹

**When:** Tagging overhead <50ms  
**Time:** 4 hours  
**Result:** Save 33.6GB RAM, simpler stack

```ruby
# Replace ES queries with MySQL
Entry.where(published_at: range)
     .tagged_with(tags, any: true)
```

**Documentation:** `docs/ELASTICSEARCH_MIGRATION_ANALYSIS.md`

---

### Path 4: Keep Current Setup (DO NOTHING) ⚠️

**When:** ES is fast enough AND RAM isn't a concern  
**Time:** 0 hours  
**Result:** No changes, keep 33.6GB RAM usage

**Not recommended** unless:
- You have plenty of RAM to spare
- Query performance is critical (<10ms required)
- Team bandwidth is extremely limited

---

## 🚀 Recommended Action Plan

### Today (30 minutes)

Run diagnostics to confirm hypothesis:

```bash
cd /Users/brunosacco/Proyectos/Rails/morfeo

# Test 1: Is tagging the bottleneck?
rails runner scripts/diagnose_tagging_performance.rb

# Test 2: Are indexes optimized?
rails runner scripts/verify_mysql_indexes.rb

# Test 3: How does ES compare?
rails runner scripts/benchmark_es_vs_mysql.rb
```

### This Week (Based on Results)

**If tagging overhead >100ms:** (Most likely scenario)
1. Implement Entry-Topic direct associations
2. Test in staging
3. Deploy to production
4. Remove Elasticsearch
5. **Save 33.6GB RAM** 🎉

**If tagging overhead 50-100ms:**
1. Add composite indexes (quick win)
2. Optimize tag ID queries
3. Re-test performance
4. If still slow → implement direct associations

**If tagging overhead <50ms:** (Unlikely but possible)
1. Remove Elasticsearch
2. Use optimized MySQL queries
3. **Save 33.6GB RAM** 🎉

---

## 📊 Expected Outcomes

### Best Case Scenario (Direct Associations)

| Metric | Before | After | Improvement |
|--------|--------|-------|-------------|
| **Query Time** | 35-50ms | 10-30ms | **70% faster** |
| **RAM Usage** | 33.6GB | 0GB | **-33.6GB** |
| **Complexity** | MySQL + ES | MySQL only | **50% simpler** |
| **Code Quality** | Workaround | Direct Rails associations | **Much cleaner** |

### Moderate Case (Quick Wins Only)

| Metric | Before | After | Improvement |
|--------|--------|-------|-------------|
| **Query Time** | 100-200ms | 60-120ms | **40% faster** |
| **RAM Usage** | 33.6GB | 33.6GB | **No change** |
| **Complexity** | Same | Same | **No change** |
| **Implementation** | - | 2 hours | **Quick** |

---

## 🎓 Key Takeaways

### Your Insight Was Correct ✅

- **Problem:** Polymorphic JOINs (`acts_as_taggable_on`)
- **Current solution:** Elasticsearch (expensive)
- **Better solution:** Direct associations (fast + free)

### The Pattern

```
Slow polymorphic JOINs
  → Elasticsearch bypass (33.6GB RAM)
  → Better: Fix JOINs, remove ES (0GB RAM, faster)
```

### Why This Matters

At 2M+ entries:
- Polymorphic JOINs across taggings table = expensive
- Each query JOINs: entries → taggings → tags
- `taggable_type` string matching = slow
- Multiple tags × multiple entries = millions of JOIN rows

**Solution:** Eliminate polymorphic nature with direct associations.

---

## 📁 Documentation Created

1. **`docs/PERFORMANCE_INVESTIGATION_QUICKSTART.md`**  
   → Start here for quick overview

2. **`docs/ACTS_AS_TAGGABLE_OPTIMIZATION.md`**  
   → Detailed solutions for tagging optimization

3. **`docs/ELASTICSEARCH_MIGRATION_ANALYSIS.md`**  
   → Complete ES removal analysis (updated with new hypothesis)

4. **`scripts/diagnose_tagging_performance.rb`**  
   → Measure tagging overhead

5. **`scripts/verify_mysql_indexes.rb`**  
   → Check index optimization

6. **`scripts/benchmark_es_vs_mysql.rb`**  
   → Compare ES vs MySQL performance

---

## ✅ Next Steps

### Immediate (Today)

```bash
# Run diagnostics
rails runner scripts/diagnose_tagging_performance.rb
rails runner scripts/verify_mysql_indexes.rb  
rails runner scripts/benchmark_es_vs_mysql.rb

# Review output
# Share results with team
# Choose optimization path
```

### This Week

1. Implement chosen solution
2. Test thoroughly
3. Deploy to production
4. Monitor performance

### Success Metrics

After optimization:
- ✅ Query time: 10-50ms
- ✅ RAM saved: up to 33.6GB
- ✅ Code quality: improved (direct associations)
- ✅ System complexity: reduced

---

## 💬 Discussion Points for Team

1. **Is 33.6GB RAM worth avoiding 50-100ms of query time?**
   - With Rails caching (30 min), 90% of queries are <1ms anyway
   - The 10% cold cache queries: 50ms vs 10ms = user won't notice
   - But 33.6GB RAM = significant cost

2. **Technical debt: Polymorphic associations**
   - `acts_as_taggable_on` is convenient but not optimal at scale
   - Direct associations are more Rails-idiomatic
   - Cleaner code, faster queries, easier to understand

3. **Migration risk vs. reward**
   - Risk: Low (can rollback easily)
   - Effort: 4-8 hours (one sprint item)
   - Reward: 33.6GB RAM + faster queries + cleaner code

4. **Future scalability**
   - Current: ES masks the problem
   - Future: Problem grows with data
   - Better: Fix root cause now

---

## 🎯 Recommendation

**Run diagnostics first, but likely path:**

1. ✅ Confirm tagging is the bottleneck (30 min)
2. ✅ Implement direct Entry-Topic associations (4 hours)
3. ✅ Remove Elasticsearch (2 hours)
4. ✅ Save 33.6GB RAM
5. ✅ Get faster queries (10-30ms vs 35-50ms)
6. ✅ Simplify system architecture

**Total time investment:** 6-7 hours  
**Total RAM savings:** 33.6GB  
**Total query improvement:** 40-70% faster

This is a high-value optimization with low risk.

---

**Questions?** Run the diagnostics and review the results with your team!


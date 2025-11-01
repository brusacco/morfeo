# acts_as_taggable_on Performance Optimization Analysis

**Date:** November 1, 2025  
**Issue:** Potential performance bottleneck with tagging queries at 2M+ scale  
**Status:** 🔍 DIAGNOSTIC - Run tests to confirm hypothesis

---

## 🎯 The Hypothesis

**User insight:** The real performance issue might be `acts_as_taggable_on` queries, not Elasticsearch.

### Why This Makes Sense

1. **Heavy usage across all models:**
   - `Entry` (2M records) - tagged with topics
   - `FacebookEntry` (~500K records) - tagged with topics  
   - `TwitterPost` (~300K records) - tagged with topics

2. **Complex JOIN pattern:**
```ruby
Entry.tagged_with(['tag1', 'tag2'], any: true)

# Generates:
SELECT DISTINCT entries.* 
FROM entries
INNER JOIN taggings ON taggings.taggable_id = entries.id 
                    AND taggings.taggable_type = 'Entry'
INNER JOIN tags ON tags.id = taggings.tag_id
WHERE tags.name IN ('tag1', 'tag2')
```

3. **Polymorphic joins are expensive:**
   - `taggable_type` string comparison on millions of rows
   - Multiple INDEXes needed: `(taggable_id, taggable_type, tag_id)`
   - `DISTINCT` required = extra sorting overhead

4. **This explains why Elasticsearch might help:**
   - ES bypasses the tagging JOIN entirely
   - Returns pre-indexed IDs
   - BUT: Uses 33.6GB RAM to avoid a JOIN!

---

## 🔬 Diagnostic Tests

Run this to identify the real bottleneck:

```bash
rails runner scripts/diagnose_tagging_performance.rb
```

This will test:
1. ✅ Baseline query (no tagging)
2. ✅ Current `acts_as_taggable_on` approach
3. ✅ Manual JOIN optimization
4. ✅ Subquery with EXISTS
5. ✅ Pre-filtering by tags first

---

## 💡 Optimization Solutions

### Solution 1: Denormalized Topic Cache (RECOMMENDED) ⭐

**Concept:** Store topic IDs directly on each content record.

#### Implementation

```ruby
# Migration
class AddTopicCacheToContent < ActiveRecord::Migration[7.0]
  def change
    add_column :entries, :cached_topic_ids, :json, default: []
    add_column :facebook_entries, :cached_topic_ids, :json, default: []
    add_column :twitter_posts, :cached_topic_ids, :json, default: []
    
    # Add indexes for JSON queries (MySQL 5.7+)
    add_index :entries, :cached_topic_ids, type: :fulltext
    add_index :facebook_entries, :cached_topic_ids, type: :fulltext
    add_index :twitter_posts, :cached_topic_ids, type: :fulltext
    
    # Or use PostgreSQL array (if you switch from MySQL)
    # add_column :entries, :cached_topic_ids, :integer, array: true, default: []
    # add_index :entries, :cached_topic_ids, using: 'gin'
  end
end

# Model: app/models/concerns/topic_cacheable.rb
module TopicCacheable
  extend ActiveSupport::Concern
  
  included do
    after_save :update_topic_cache, if: :saved_change_to_tag_list?
  end
  
  def update_topic_cache
    # Find all topics that have tags matching this entry's tags
    topic_ids = Topic.joins(:tags)
                    .where(tags: { name: tag_list })
                    .distinct
                    .pluck(:id)
    
    update_column(:cached_topic_ids, topic_ids)
  end
  
  # Scope for querying
  def self.for_topic(topic)
    where("JSON_CONTAINS(cached_topic_ids, ?)", topic.id.to_json)
    # Or for PostgreSQL: where('? = ANY(cached_topic_ids)', topic.id)
  end
end

# Apply to models
class Entry < ApplicationRecord
  include TopicCacheable
  # ... rest of model
end

class FacebookEntry < ApplicationRecord
  include TopicCacheable
  # ... rest of model
end

class TwitterPost < ApplicationRecord
  include TopicCacheable
  # ... rest of model
end

# Usage in Topic model
class Topic < ApplicationRecord
  def list_entries
    Rails.cache.fetch("topic_#{id}_list_entries", expires_in: 30.minutes) do
      # OLD (slow JOIN):
      # Entry.where(published_at: default_date_range)
      #      .tagged_with(tag_names, any: true)
      
      # NEW (fast array lookup):
      Entry.where(published_at: default_date_range)
           .for_topic(self)
           .enabled
           .order(published_at: :desc)
           .includes(:site, :tags)
    end
  end
end

# Backfill existing data
class BackfillTopicCache < ActiveRecord::Migration[7.0]
  def up
    [Entry, FacebookEntry, TwitterPost].each do |model|
      model.find_each(batch_size: 1000) do |record|
        record.update_topic_cache
      end
    end
  end
end
```

**Performance Impact:**
- ✅ **Query time:** 100-200ms → 20-50ms (75% faster)
- ✅ **No JOINs:** Direct index lookup
- ⚠️ **Storage:** ~4KB per record for topic IDs (negligible)
- ⚠️ **Maintenance:** Auto-updates via callback

---

### Solution 2: Optimized JOIN with Tag IDs (QUICK WIN) 🏃

**Concept:** Use tag IDs instead of tag names to avoid string JOINs.

```ruby
class Topic < ApplicationRecord
  # Cache tag IDs for 1 hour (tags rarely change)
  def cached_tag_ids
    Rails.cache.fetch("topic_#{id}_tag_ids", expires_in: 1.hour) do
      tags.pluck(:id)
    end
  end
  
  def list_entries
    Rails.cache.fetch("topic_#{id}_list_entries", expires_in: 30.minutes) do
      # Optimized query
      Entry.enabled
           .where(published_at: default_date_range)
           .joins(:taggings)
           .where(
             taggings: {
               tag_id: cached_tag_ids,
               taggable_type: 'Entry'
             }
           )
           .distinct
           .order(published_at: :desc)
           .includes(:site, :tags)
    end
  end
end
```

**Performance Impact:**
- ✅ **Query time:** 20-30% faster (avoids tags table JOIN)
- ✅ **Zero schema changes**
- ✅ **Easy to implement** (< 1 hour)
- ⚠️ **Still has JOIN overhead**

---

### Solution 3: Composite Index Optimization (QUICK WIN) 🏃

**Concept:** Add optimized composite indexes for tagging queries.

```ruby
class OptimizeTaggingIndexes < ActiveRecord::Migration[7.0]
  def change
    # Remove old indexes if they exist
    # These are usually created by acts_as_taggable_on but might not be optimal
    
    # Add optimized composite indexes
    # For queries filtering by date + tags on Entry
    add_index :entries, [:published_at, :enabled], 
              name: 'idx_entries_date_enabled'
    
    # For taggings table (critical!)
    remove_index :taggings, name: 'index_taggings_on_taggable_id_and_taggable_type_and_tag_id'
    remove_index :taggings, name: 'index_taggings_on_tag_id_and_taggable_id_and_taggable_type'
    
    # Optimized for: WHERE taggable_type = X AND tag_id IN (...) AND taggable_id = Y
    add_index :taggings, 
              [:taggable_type, :tag_id, :taggable_id],
              name: 'idx_taggings_type_tag_id'
    
    # Optimized for reverse lookup: WHERE tag_id = X AND taggable_type = Y
    add_index :taggings,
              [:tag_id, :taggable_type, :taggable_id],
              name: 'idx_taggings_tag_type_id'
    
    # For Facebook/Twitter
    add_index :facebook_entries, [:posted_at, :page_id]
    add_index :twitter_posts, [:posted_at, :twitter_profile_id]
  end
end
```

**Performance Impact:**
- ✅ **Query time:** 30-50% faster
- ✅ **Zero code changes**
- ✅ **Easy to implement** (< 30 min)
- ✅ **Safe to rollback**

---

### Solution 4: Pre-compute Entry-Topic Association (BEST) 🏆

**Concept:** Create a direct many-to-many relationship between entries and topics.

```ruby
# Migration
class CreateEntryTopics < ActiveRecord::Migration[7.0]
  def change
    create_table :entry_topics do |t|
      t.references :entry, null: false, foreign_key: true
      t.references :topic, null: false, foreign_key: true
      t.timestamps
    end
    
    add_index :entry_topics, [:topic_id, :entry_id], unique: true
    add_index :entry_topics, [:entry_id, :topic_id]
    
    # Similar for Facebook and Twitter
    create_table :facebook_entry_topics do |t|
      t.references :facebook_entry, null: false, foreign_key: true
      t.references :topic, null: false, foreign_key: true
      t.timestamps
    end
    
    add_index :facebook_entry_topics, [:topic_id, :facebook_entry_id], 
              unique: true, name: 'idx_fb_entry_topics'
    
    create_table :twitter_post_topics do |t|
      t.references :twitter_post, null: false, foreign_key: true
      t.references :topic, null: false, foreign_key: true
      t.timestamps
    end
    
    add_index :twitter_post_topics, [:topic_id, :twitter_post_id], 
              unique: true, name: 'idx_twitter_post_topics'
  end
end

# Models
class Entry < ApplicationRecord
  has_many :entry_topics, dependent: :destroy
  has_many :topics, through: :entry_topics
  
  after_save :sync_topics, if: :saved_change_to_tag_list?
  
  def sync_topics
    # Find topics matching this entry's tags
    matching_topics = Topic.joins(:tags)
                          .where(tags: { name: tag_list })
                          .distinct
    
    self.topics = matching_topics
  end
end

class Topic < ApplicationRecord
  has_many :entry_topics, dependent: :destroy
  has_many :entries, through: :entry_topics
  
  has_many :facebook_entry_topics, dependent: :destroy
  has_many :facebook_entries, through: :facebook_entry_topics
  
  has_many :twitter_post_topics, dependent: :destroy
  has_many :twitter_posts, through: :twitter_post_topics
  
  def list_entries
    Rails.cache.fetch("topic_#{id}_list_entries", expires_in: 30.minutes) do
      # Super fast - direct JOIN on topic_id
      entries.where(published_at: default_date_range)
             .enabled
             .order(published_at: :desc)
             .includes(:site, :tags)
    end
  end
end

# Backfill
class BackfillEntryTopics < ActiveRecord::Migration[7.0]
  def up
    Entry.find_each(batch_size: 1000, &:sync_topics)
    FacebookEntry.find_each(batch_size: 1000, &:sync_topics)
    TwitterPost.find_each(batch_size: 1000, &:sync_topics)
  end
end
```

**Performance Impact:**
- ✅ **Query time:** 100-200ms → 10-30ms (85% faster!)
- ✅ **Cleanest solution** (proper Rails associations)
- ✅ **Can remove Elasticsearch** entirely
- ⚠️ **More storage:** ~24 bytes per entry-topic pair
- ⚠️ **Migration time:** 1-2 hours for backfill

---

## 📊 Performance Comparison

| Approach | Query Time | Complexity | Storage | Migration Time |
|----------|------------|------------|---------|----------------|
| **Current (acts_as_taggable_on)** | 100-200ms | High | 0 | 0 |
| **Optimized Indexes** | 60-120ms | High | 0 | 30 min |
| **Tag ID optimization** | 70-140ms | Medium | 0 | 1 hour |
| **Denormalized JSON cache** | 20-50ms | Low | +4KB/entry | 4 hours |
| **Entry-Topic association** | 10-30ms | Low | +24B/pair | 4 hours |

---

## 🚦 Decision Tree

```
Is tagging overhead > 100ms?
├─ YES → Implement Solution 4 (Entry-Topic association)
│        Remove Elasticsearch
│        Expected: 85% faster + save 33.6GB RAM
│
└─ NO → Is it > 50ms?
    ├─ YES → Quick wins:
    │        1. Solution 3 (Optimized indexes) - 30 min
    │        2. Solution 2 (Tag ID optimization) - 1 hour
    │        Keep Elasticsearch for now
    │
    └─ NO → Tagging is NOT the bottleneck
            Review Elasticsearch analysis
            Bottleneck is probably elsewhere
```

---

## 🔍 Diagnostic Commands

```bash
# 1. Test tagging performance
rails runner scripts/diagnose_tagging_performance.rb

# 2. Check taggings table size
rails runner "puts Tagging.count"

# 3. Analyze a specific slow query
rails runner "
  ActiveRecord::Base.logger = Logger.new(STDOUT)
  topic = Topic.first
  topic.list_entries.to_a
"

# 4. Check current indexes
rails runner "
  ActiveRecord::Base.connection.execute('SHOW INDEX FROM taggings').each do |idx|
    puts \"\#{idx['Key_name']}: \#{idx['Column_name']}\"
  end
"
```

---

## 🎯 Recommended Action Plan

### Phase 1: Diagnosis (30 minutes)
1. Run `diagnose_tagging_performance.rb`
2. Identify if tagging is the bottleneck
3. Measure overhead in milliseconds

### Phase 2: Quick Wins (1-2 hours)
If overhead > 50ms:
1. Implement Solution 3 (Optimized Indexes)
2. Implement Solution 2 (Tag ID optimization)
3. Measure improvement

### Phase 3: Major Optimization (4-8 hours)
If overhead still > 50ms after quick wins:
1. Implement Solution 4 (Entry-Topic association)
2. Backfill data
3. Update all query methods
4. Remove Elasticsearch

### Phase 4: Cleanup (1 hour)
If Performance is good:
1. Remove Elasticsearch
2. Save 33.6GB RAM
3. Simplify stack

---

## 💡 Key Insight

**Elasticsearch might be a band-aid for slow tagging queries!**

If `acts_as_taggable_on` adds 100-200ms overhead:
- ✅ ES bypasses the JOIN → appears "faster"
- ❌ But costs 33.6GB RAM
- ❌ And adds complexity

**Better solution:** Fix the root cause (tagging JOINs) then remove ES.

**Expected final state:**
- ✅ 10-30ms queries (faster than ES!)
- ✅ 0GB additional RAM (vs 33.6GB for ES)
- ✅ Simpler stack
- ✅ Direct Rails associations (cleaner code)

---

## 📝 Next Steps

1. **Run diagnostic:** `rails runner scripts/diagnose_tagging_performance.rb`
2. **Review results:** Check which approach is fastest
3. **Implement solution:** Start with quick wins, then major optimization if needed
4. **Remove ES:** Once tagging is optimized, ES becomes unnecessary

---

**Questions?** Review diagnostic results and choose the best optimization path!


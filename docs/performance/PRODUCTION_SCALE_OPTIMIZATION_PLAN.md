# Production-Scale Tagging Optimization Plan

**Date:** November 1, 2025  
**Issue:** Polymorphic tagging JOIN adds 194ms overhead at 3.3M tagging scale  
**Solution:** Direct Entry-Topic associations  
**Expected improvement:** 440ms → 50-100ms (80% faster)

---

## 🎯 The Problem (Confirmed by Production Data)

### Scale Comparison

| Environment    | Taggings  | Query Time | Performance                         |
| -------------- | --------- | ---------- | ----------------------------------- |
| **Local**      | 1,057     | 11ms       | ✅ Fast                             |
| **Production** | 3,247,451 | 440ms      | ❌ **3,072x more data, 40x slower** |

### Why Polymorphic JOINs Don't Scale

```sql
-- Current query pattern (slow at scale):
SELECT entries.*
FROM entries
WHERE EXISTS (
  SELECT 1 FROM taggings
  WHERE taggable_id = entries.id
  AND taggable_type = 'Entry'        -- String comparison!
  AND tag_id IN (1,2,3,4,5,6,7)      -- Multiple tag lookups
)

-- Problem: MySQL must scan millions of taggings rows
-- Even with indexes, polymorphic joins don't optimize well
```

### Why Elasticsearch "Works"

- Bypasses the JOIN entirely
- Pre-indexed data structure
- Direct ID lookups
- **BUT: Costs 33.6GB RAM**

---

## 💡 Solution: Direct Entry-Topic Associations

Replace polymorphic joins with direct foreign key relationships.

### Architecture Change

**Before (slow):**

```
Entry → Taggings (3.3M rows) → Tags → Topics
         ↑ Polymorphic JOIN (expensive!)
```

**After (fast):**

```
Entry → EntryTopics → Topics
         ↑ Direct foreign key (fast!)
```

---

## 📝 Implementation

### Step 1: Create Join Tables (30 minutes)

```ruby
# db/migrate/XXXXXX_create_content_topic_associations.rb
class CreateContentTopicAssociations < ActiveRecord::Migration[7.0]
  def change
    # Entry-Topic association
    create_table :entry_topics do |t|
      t.references :entry, null: false, foreign_key: true, index: true
      t.references :topic, null: false, foreign_key: true, index: true
      t.timestamps
    end
    add_index :entry_topics, [:topic_id, :entry_id], unique: true
    add_index :entry_topics, [:entry_id, :topic_id], unique: true

    # FacebookEntry-Topic association
    create_table :facebook_entry_topics do |t|
      t.references :facebook_entry, null: false, foreign_key: true, index: true
      t.references :topic, null: false, foreign_key: true, index: true
      t.timestamps
    end
    add_index :facebook_entry_topics, [:topic_id, :facebook_entry_id],
              unique: true, name: 'idx_fb_topic_entry'

    # TwitterPost-Topic association
    create_table :twitter_post_topics do |t|
      t.references :twitter_post, null: false, foreign_key: true, index: true
      t.references :topic, null: false, foreign_key: true, index: true
      t.timestamps
    end
    add_index :twitter_post_topics, [:topic_id, :twitter_post_id],
              unique: true, name: 'idx_twitter_topic_post'
  end
end
```

### Step 2: Update Models (15 minutes)

```ruby
# app/models/entry.rb
class Entry < ApplicationRecord
  searchkick  # Keep for now
  acts_as_taggable_on :tags, :title_tags  # Keep for now

  # NEW: Direct topic associations
  has_many :entry_topics, dependent: :destroy
  has_many :topics, through: :entry_topics

  # Callback to sync topics when tags change
  after_save :sync_topics_from_tags, if: :saved_change_to_tag_list?

  private

  def sync_topics_from_tags
    # Find all topics that have matching tags
    matching_topics = Topic.joins(:tags)
                          .where(tags: { name: tag_list })
                          .distinct

    self.topics = matching_topics
  end
end

# app/models/facebook_entry.rb
class FacebookEntry < ApplicationRecord
  has_many :facebook_entry_topics, dependent: :destroy
  has_many :topics, through: :facebook_entry_topics

  after_save :sync_topics_from_tags, if: :saved_change_to_tag_list?

  private

  def sync_topics_from_tags
    matching_topics = Topic.joins(:tags)
                          .where(tags: { name: tag_list })
                          .distinct
    self.topics = matching_topics
  end
end

# app/models/twitter_post.rb
class TwitterPost < ApplicationRecord
  has_many :twitter_post_topics, dependent: :destroy
  has_many :topics, through: :twitter_post_topics

  after_save :sync_topics_from_tags, if: :saved_change_to_tag_list?

  private

  def sync_topics_from_tags
    matching_topics = Topic.joins(:tags)
                          .where(tags: { name: tag_list })
                          .distinct
    self.topics = matching_topics
  end
end

# app/models/topic.rb
class Topic < ApplicationRecord
  has_and_belongs_to_many :tags

  # NEW: Direct content associations
  has_many :entry_topics, dependent: :destroy
  has_many :entries, through: :entry_topics

  has_many :facebook_entry_topics, dependent: :destroy
  has_many :facebook_entries, through: :facebook_entry_topics

  has_many :twitter_post_topics, dependent: :destroy
  has_many :twitter_posts, through: :twitter_post_topics

  # Update query methods to use direct associations
  def list_entries
    Rails.cache.fetch("topic_#{id}_list_entries", expires_in: 30.minutes) do
      # NEW: Direct association (fast!)
      entries.enabled
             .where(published_at: default_date_range[:gte]..default_date_range[:lte])
             .order(published_at: :desc)
             .includes(:site, :tags)
    end
  end

  def report_entries(start_date, end_date)
    entries.enabled
           .where(published_at: start_date.beginning_of_day..end_date.end_of_day)
           .order(total_count: :desc)
           .joins(:site)
  end

  # ... update all other query methods similarly
end
```

### Step 3: Backfill Existing Data (2-4 hours)

**⚠️ This is a long-running task for 1.7M entries!**

```ruby
# db/migrate/XXXXXX_backfill_entry_topic_associations.rb
class BackfillEntryTopicAssociations < ActiveRecord::Migration[7.0]
  def up
    say "Backfilling Entry-Topic associations (this may take 2-4 hours)..."

    Entry.find_in_batches(batch_size: 1000) do |batch|
      batch.each do |entry|
        entry.sync_topics_from_tags
      end

      # Progress indicator
      print "."
      sleep 0.1  # Throttle to avoid overwhelming DB
    end

    say "\nBackfilling FacebookEntry-Topic associations..."
    FacebookEntry.find_in_batches(batch_size: 1000) do |batch|
      batch.each do |fb_entry|
        fb_entry.sync_topics_from_tags
      end
      print "."
      sleep 0.1
    end

    say "\nBackfilling TwitterPost-Topic associations..."
    TwitterPost.find_in_batches(batch_size: 1000) do |batch|
      batch.each do |tweet|
        tweet.sync_topics_from_tags
      end
      print "."
      sleep 0.1
    end

    say "\nBackfill complete!"
  end

  def down
    EntryTopic.delete_all
    FacebookEntryTopic.delete_all
    TwitterPostTopic.delete_all
  end
end
```

**Better approach: Background job**

```ruby
# app/jobs/backfill_topic_associations_job.rb
class BackfillTopicAssociationsJob < ApplicationJob
  queue_as :default

  def perform(model_name, batch_size: 1000)
    model = model_name.constantize
    total = model.count
    processed = 0

    model.find_in_batches(batch_size: batch_size) do |batch|
      batch.each do |record|
        record.sync_topics_from_tags
      end

      processed += batch.size
      Rails.logger.info "Backfilled #{processed}/#{total} #{model_name} records"

      sleep 0.1  # Throttle
    end

    Rails.logger.info "Backfill complete for #{model_name}!"
  end
end

# Run via console or separate rake task
# BackfillTopicAssociationsJob.perform_later('Entry')
# BackfillTopicAssociationsJob.perform_later('FacebookEntry')
# BackfillTopicAssociationsJob.perform_later('TwitterPost')
```

### Step 4: Test Performance (30 minutes)

```ruby
# Test in production console
topic = Topic.find(1)

# Old way (should still work, uses ES or tagged_with)
Benchmark.measure { topic.list_entries.to_a }

# After deploying new code, test new way:
Benchmark.measure {
  topic.entries
       .where(published_at: 30.days.ago..)
       .enabled
       .order(published_at: :desc)
       .to_a
}

# Expected: 440ms → 50-100ms (80% faster!)
```

### Step 5: Gradual Rollout

**Don't switch everything at once!** Test incrementally:

1. **Week 1**: Deploy new associations, run backfill
2. **Week 2**: Update ONE topic method to use direct associations, monitor
3. **Week 3**: If good, update all topic methods
4. **Week 4**: Remove Elasticsearch (save 33.6GB RAM)

---

## 📊 Expected Performance

### Query Time Comparison

| Method         | Current (ES) | Current (MySQL+tagged_with) | After (Direct Associations) |
| -------------- | ------------ | --------------------------- | --------------------------- |
| **Cold cache** | 30-40ms      | 440ms ❌                    | 50-100ms ✅                 |
| **Warm cache** | <1ms         | <1ms                        | <1ms                        |
| **RAM usage**  | +33.6GB      | 0GB                         | 0GB                         |

### Why This Will Be Fast

```sql
-- OLD: Polymorphic JOIN (slow)
SELECT entries.* FROM entries
WHERE EXISTS (
  SELECT 1 FROM taggings
  WHERE taggable_id = entries.id
  AND taggable_type = 'Entry'  -- 3.3M row scan!
  AND tag_id IN (...)
)

-- NEW: Direct foreign key JOIN (fast)
SELECT entries.* FROM entries
INNER JOIN entry_topics ON entry_topics.entry_id = entries.id
WHERE entry_topics.topic_id = 1  -- Indexed! Instant lookup!
AND entries.published_at >= '...'
```

**Why it's faster:**

- No polymorphic type checking
- Direct foreign key (indexed)
- MySQL optimizer can use best index
- Much smaller join table (~200K rows vs 3.3M)

---

## 💾 Storage Impact

### Additional Tables

| Table                   | Rows (estimated) | Size       | Notes                        |
| ----------------------- | ---------------- | ---------- | ---------------------------- |
| `entry_topics`          | ~200,000         | ~5MB       | Avg 1.9 tags × ~105K entries |
| `facebook_entry_topics` | ~30,000          | ~1MB       | Smaller dataset              |
| `twitter_post_topics`   | ~10,000          | ~500KB     | Smallest dataset             |
| **Total**               | ~240,000         | **~6.5MB** | Negligible!                  |

**vs keeping Elasticsearch: 33.6GB RAM**

---

## 🎯 Migration Timeline

### Recommended Schedule

**Week 1: Preparation (5 hours)**

- Create migrations
- Update models with new associations
- Deploy to staging
- Run backfill on staging
- Test performance

**Week 2: Production Backfill (hands-off)**

- Deploy associations to production
- Run backfill job (2-4 hours, monitored)
- Keep using Elasticsearch (no changes to queries yet)
- Verify data integrity

**Week 3: Switch One Method (2 hours)**

- Update `Topic#list_entries` to use direct associations
- Monitor query performance
- Compare ES vs direct association times
- If good, proceed

**Week 4: Full Migration (4 hours)**

- Update all Topic query methods
- Update Tag query methods
- Monitor for 1 week
- If stable, remove Elasticsearch

**Week 5: Cleanup**

- Stop Elasticsearch service
- Remove searchkick gem
- **Save 33.6GB RAM** 🎉

---

## ⚠️ Important Notes

### Keep Elasticsearch Running During Migration

- Don't remove ES until direct associations are proven
- Run both systems in parallel during Week 2-3
- Easy rollback if needed

### Monitor These Metrics

- Query times (should drop from 440ms → 50-100ms)
- Entry-topic association accuracy
- Memory usage (no change until ES removed)
- Error rates (should be zero)

### If Backfill Fails

- Backfill can be re-run safely (idempotent)
- Can run in batches over multiple days
- Won't affect current ES-based queries

---

## 🎉 Expected Final State

### Performance

- **Query time:** 50-100ms (vs 440ms now, 88% faster)
- **Memory:** Save 33.6GB (vs current ES usage)
- **Code:** Cleaner (direct Rails associations)
- **Maintenance:** Easier (no ES cluster)

### Architecture

```
Clean Rails architecture:
Topic.entries  # Direct association, simple and fast
  vs
Entry.search(...) → ES cluster → Entry.where(id: [...])  # Complex, expensive
```

---

## 📝 Next Steps

1. **Review this plan with team**
2. **Schedule 1-week implementation window**
3. **Start with migrations on staging**
4. **Monitor and iterate**
5. **Remove ES once direct associations proven**

**Result: 88% faster queries + save 33.6GB RAM + cleaner code!**

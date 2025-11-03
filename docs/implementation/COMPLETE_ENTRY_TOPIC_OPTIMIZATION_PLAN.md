# Complete Entry Tagging Optimization Implementation Plan

**Project:** Replace polymorphic tagging with direct Entry-Topic associations  
**Goal:** Reduce query time from 440ms to 50-100ms (80-88% improvement)  
**Secondary Goal:** Enable Elasticsearch removal (save 33.6GB RAM)  
**Timeline:** 5 weeks  
**Estimated Effort:** 30-35 hours

---

## 📋 Table of Contents

1. [Executive Summary](#executive-summary)
2. [Phase 1: Week 1 - Infrastructure Setup](#phase-1-week-1---infrastructure-setup)
3. [Phase 2: Week 2 - Production Backfill](#phase-2-week-2---production-backfill)
4. [Phase 3: Week 3 - Parallel Testing](#phase-3-week-3---parallel-testing)
5. [Phase 4: Week 4 - Full Switchover](#phase-4-week-4---full-switchover)
6. [Phase 5: Week 5 - Elasticsearch Cleanup](#phase-5-week-5---elasticsearch-cleanup)
7. [Testing & Validation](#testing--validation)
8. [Monitoring & Metrics](#monitoring--metrics)
9. [Rollback Procedures](#rollback-procedures)
10. [Appendix: All Code Files](#appendix-all-code-files)

---

## Executive Summary

### The Problem

At production scale (1.7M entries, 3.3M taggings):
- Tagging queries take 440ms (vs 246ms baseline)
- Polymorphic JOIN scans millions of rows
- Elasticsearch currently masks this (but costs 33.6GB RAM)

### The Solution

Create direct `Entry ↔ Topic` associations:
- `entry_topics` table (for regular tags)
- `entry_title_topics` table (for title tags)
- Eliminate polymorphic JOINs
- Expected: 440ms → 50-100ms

### Risk Assessment

| Risk | Likelihood | Impact | Mitigation |
|------|------------|--------|------------|
| Backfill failure | Low | Medium | Batchable, retryable, monitored |
| Data mismatch | Low | High | Validation scripts at every stage |
| Performance regression | Very Low | Medium | Feature flags, easy rollback |
| Downtime | Very Low | High | Zero-downtime deployment |

**Overall Risk:** LOW - Safe, gradual migration with multiple checkpoints

---

## Phase 1: Week 1 - Infrastructure Setup

**Duration:** 8 hours  
**Goal:** Create tables, models, jobs; deploy to staging; validate

### Step 1.1: Create Migrations (30 minutes)

Create file: `db/migrate/20251101000001_create_entry_topic_associations.rb`

```ruby
class CreateEntryTopicAssociations < ActiveRecord::Migration[7.0]
  def change
    # Regular tags → entry_topics
    create_table :entry_topics do |t|
      t.references :entry, null: false, foreign_key: true
      t.references :topic, null: false, foreign_key: true
      t.timestamps
    end
    
    # Composite indexes for fast lookups in both directions
    add_index :entry_topics, [:entry_id, :topic_id], unique: true, name: 'idx_entry_topics_unique'
    add_index :entry_topics, [:topic_id, :entry_id], name: 'idx_topic_entries'
    
    # Title tags → entry_title_topics
    create_table :entry_title_topics do |t|
      t.references :entry, null: false, foreign_key: true
      t.references :topic, null: false, foreign_key: true
      t.timestamps
    end
    
    # Composite indexes for fast lookups in both directions
    add_index :entry_title_topics, [:entry_id, :topic_id], unique: true, name: 'idx_entry_title_topics_unique'
    add_index :entry_title_topics, [:topic_id, :entry_id], name: 'idx_topic_title_entries'
  end
end
```

**Run migration:**
```bash
# On local/staging
rails db:migrate

# Verify tables created
rails dbconsole
> SHOW TABLES LIKE '%entry%topic%';
> DESCRIBE entry_topics;
> DESCRIBE entry_title_topics;
> exit
```

### Step 1.2: Update Entry Model (45 minutes)

Edit: `app/models/entry.rb`

```ruby
# frozen_string_literal: true

class Entry < ApplicationRecord
  # Existing (keep for now during migration)
  searchkick
  acts_as_taggable_on :tags, :title_tags
  
  # Existing associations
  belongs_to :site, touch: true
  has_many :comments, dependent: :destroy
  has_one :twitter_post, dependent: :nullify
  
  # NEW: Direct topic associations
  has_many :entry_topics, dependent: :destroy
  has_many :topics, through: :entry_topics
  
  has_many :entry_title_topics, dependent: :destroy
  has_many :title_topics, through: :entry_title_topics, source: :topic
  
  # NEW: Auto-sync callbacks (critical!)
  after_save :sync_topics_from_tags, if: :saved_change_to_tag_list?
  after_save :sync_title_topics_from_tags, if: :saved_change_to_title_tag_list?
  
  # NEW: Scoped query methods
  scope :for_topic, ->(topic) {
    topic_id = topic.is_a?(Topic) ? topic.id : topic
    joins(:entry_topics).where(entry_topics: { topic_id: topic_id })
  }
  
  scope :for_topic_title, ->(topic) {
    topic_id = topic.is_a?(Topic) ? topic.id : topic
    joins(:entry_title_topics).where(entry_title_topics: { topic_id: topic_id })
  }
  
  # ... rest of existing model code ...
  
  private
  
  # NEW: Sync regular tags to topics
  def sync_topics_from_tags
    return if tag_list.empty?
    
    # Find all topics that have tags matching this entry's tags
    matching_topics = Topic.joins(:tags)
                          .where(tags: { name: tag_list })
                          .distinct
    
    # Update the association (Rails handles the join table)
    self.topics = matching_topics
    
    Rails.logger.info "Entry #{id}: Synced #{matching_topics.count} topics from tags"
  rescue => e
    Rails.logger.error "Entry #{id}: Failed to sync topics - #{e.message}"
    # Don't raise - this shouldn't break entry creation
  end
  
  # NEW: Sync title tags to topics
  def sync_title_topics_from_tags
    return if title_tag_list.empty?
    
    # Find all topics that have tags matching this entry's title tags
    matching_topics = Topic.joins(:tags)
                          .where(tags: { name: title_tag_list })
                          .distinct
    
    # Update the association
    self.title_topics = matching_topics
    
    Rails.logger.info "Entry #{id}: Synced #{matching_topics.count} title topics from tags"
  rescue => e
    Rails.logger.error "Entry #{id}: Failed to sync title topics - #{e.message}"
  end
end
```

### Step 1.3: Update Topic Model (30 minutes)

Edit: `app/models/topic.rb`

Add at the top of the model:

```ruby
class Topic < ApplicationRecord
  # Existing associations
  has_paper_trail on: %i[create destroy update]
  has_many :topic_stat_dailies, dependent: :destroy
  has_many :title_topic_stat_dailies, dependent: :destroy
  has_many :user_topics, dependent: :destroy
  has_many :users, through: :user_topics
  has_many :reports, dependent: :destroy
  has_many :templates, dependent: :destroy
  has_and_belongs_to_many :tags
  
  # NEW: Direct entry associations
  has_many :entry_topics, dependent: :destroy
  has_many :entries, through: :entry_topics
  
  has_many :entry_title_topics, dependent: :destroy
  has_many :title_entries, through: :entry_title_topics, source: :entry
  
  # ... rest of existing model code ...
  
  # NEW: Helper method to get all entries (tags + title_tags combined)
  def all_tagged_entries
    Entry.where(id: entries.pluck(:id) + title_entries.pluck(:id)).distinct
  end
end
```

### Step 1.4: Create Join Table Models (15 minutes)

Create file: `app/models/entry_topic.rb`

```ruby
# frozen_string_literal: true

class EntryTopic < ApplicationRecord
  belongs_to :entry
  belongs_to :topic
  
  validates :entry_id, uniqueness: { scope: :topic_id }
  
  # Useful for debugging
  scope :recent, -> { order(created_at: :desc) }
end
```

Create file: `app/models/entry_title_topic.rb`

```ruby
# frozen_string_literal: true

class EntryTitleTopic < ApplicationRecord
  belongs_to :entry
  belongs_to :topic
  
  validates :entry_id, uniqueness: { scope: :topic_id }
  
  # Useful for debugging
  scope :recent, -> { order(created_at: :desc) }
end
```

### Step 1.5: Create Backfill Job (1 hour)

Create file: `app/jobs/backfill_entry_topics_job.rb`

```ruby
# frozen_string_literal: true

class BackfillEntryTopicsJob < ApplicationJob
  queue_as :default
  
  def perform(batch_size: 500, start_id: nil, end_id: nil)
    start_time = Time.current
    total_entries = Entry.count
    processed = 0
    skipped = 0
    errors = []
    
    Rails.logger.info "=" * 80
    Rails.logger.info "Starting Entry-Topic backfill"
    Rails.logger.info "Total entries: #{total_entries}"
    Rails.logger.info "Batch size: #{batch_size}"
    Rails.logger.info "Start ID: #{start_id || 'beginning'}"
    Rails.logger.info "End ID: #{end_id || 'end'}"
    Rails.logger.info "=" * 80
    
    # Build query
    query = Entry.order(:id)
    query = query.where('id >= ?', start_id) if start_id
    query = query.where('id <= ?', end_id) if end_id
    
    # Process in batches
    query.find_in_batches(batch_size: batch_size) do |batch|
      batch.each do |entry|
        begin
          # Sync both tag types
          synced_tags = sync_entry_tags(entry)
          synced_title_tags = sync_entry_title_tags(entry)
          
          processed += 1
          
          # Log progress every 100 entries
          if processed % 100 == 0
            elapsed = Time.current - start_time
            rate = processed / elapsed
            remaining = (total_entries - processed) / rate
            
            Rails.logger.info "[#{processed}/#{total_entries}] " \
                            "Rate: #{rate.round(1)}/sec | " \
                            "ETA: #{remaining.to_i}sec | " \
                            "Entry #{entry.id}: #{synced_tags} tags, #{synced_title_tags} title tags"
          end
        rescue => e
          errors << {
            entry_id: entry.id,
            error: e.message,
            backtrace: e.backtrace.first(3)
          }
          Rails.logger.error "Entry #{entry.id} FAILED: #{e.message}"
          skipped += 1
        end
      end
      
      # Throttle to avoid overwhelming database
      sleep 0.05
    end
    
    # Final report
    duration = Time.current - start_time
    Rails.logger.info "=" * 80
    Rails.logger.info "Backfill complete!"
    Rails.logger.info "Duration: #{duration.round(2)}s"
    Rails.logger.info "Processed: #{processed}"
    Rails.logger.info "Skipped: #{skipped}"
    Rails.logger.info "Errors: #{errors.size}"
    Rails.logger.info "Rate: #{(processed / duration).round(2)} entries/sec"
    Rails.logger.info "=" * 80
    
    if errors.any?
      Rails.logger.error "Errors encountered:"
      errors.each do |err|
        Rails.logger.error "  Entry #{err[:entry_id]}: #{err[:error]}"
      end
    end
    
    {
      processed: processed,
      skipped: skipped,
      errors: errors,
      duration: duration
    }
  end
  
  private
  
  def sync_entry_tags(entry)
    return 0 if entry.tag_list.empty?
    
    matching_topics = Topic.joins(:tags)
                          .where(tags: { name: entry.tag_list })
                          .distinct
    
    entry.topics = matching_topics
    matching_topics.count
  end
  
  def sync_entry_title_tags(entry)
    return 0 if entry.title_tag_list.empty?
    
    matching_topics = Topic.joins(:tags)
                          .where(tags: { name: entry.title_tag_list })
                          .distinct
    
    entry.title_topics = matching_topics
    matching_topics.count
  end
end
```

### Step 1.6: Create Validation Script (45 minutes)

Create file: `lib/tasks/validate_entry_topics.rake`

```ruby
# frozen_string_literal: true

namespace :entry_topics do
  desc "Validate Entry-Topic associations match tagging"
  task validate: :environment do
    puts "\n" + "=" * 80
    puts "Entry-Topic Association Validation"
    puts "=" * 80
    
    # Test all active topics
    Topic.active.each do |topic|
      validate_topic(topic)
    end
    
    puts "\n" + "=" * 80
    puts "Validation complete!"
    puts "=" * 80
  end
  
  desc "Validate specific topic by ID"
  task :validate_topic, [:topic_id] => :environment do |t, args|
    topic = Topic.find(args[:topic_id])
    validate_topic(topic, verbose: true)
  end
  
  desc "Performance benchmark old vs new"
  task :benchmark, [:topic_id] => :environment do |t, args|
    require 'benchmark'
    
    topic = Topic.find(args[:topic_id])
    
    puts "\n" + "=" * 80
    puts "Performance Benchmark: #{topic.name}"
    puts "=" * 80
    
    # Warm up
    Entry.enabled.tagged_with(topic.tag_names, any: true).count
    topic.entries.enabled.count
    
    # Old method (tagged_with)
    old_time = Benchmark.measure do
      Entry.enabled
           .where(published_at: 30.days.ago..)
           .tagged_with(topic.tag_names, any: true)
           .to_a
    end
    
    # New method (direct association)
    new_time = Benchmark.measure do
      topic.entries
           .enabled
           .where(published_at: 30.days.ago..)
           .to_a
    end
    
    puts "\nResults:"
    puts "  Old method (tagged_with): #{(old_time.real * 1000).round(2)}ms"
    puts "  New method (association): #{(new_time.real * 1000).round(2)}ms"
    
    if new_time.real < old_time.real
      improvement = ((old_time.real - new_time.real) / old_time.real * 100).round(1)
      puts "  ✅ #{improvement}% FASTER"
    else
      degradation = ((new_time.real - old_time.real) / old_time.real * 100).round(1)
      puts "  ⚠️  #{degradation}% SLOWER"
    end
    
    puts "=" * 80
  end
  
  def validate_topic(topic, verbose: false)
    print "Testing #{topic.name}... "
    
    # Count entries via old method (tagged_with)
    old_count = Entry.enabled.tagged_with(topic.tag_names, any: true).count
    
    # Count entries via new method (association)
    new_count = topic.entries.enabled.count
    
    # Count title entries
    old_title_count = Entry.enabled.tagged_with(topic.tag_names, any: true, on: :title_tags).count
    new_title_count = topic.title_entries.enabled.count
    
    # Check match
    tags_match = old_count == new_count
    title_tags_match = old_title_count == new_title_count
    
    if tags_match && title_tags_match
      puts "✅ PASS"
    else
      puts "❌ FAIL"
      puts "  Tags: #{old_count} (old) vs #{new_count} (new)"
      puts "  Title: #{old_title_count} (old) vs #{new_title_count} (new)"
    end
    
    if verbose
      puts "\nDetailed Results:"
      puts "  Regular tags:"
      puts "    tagged_with: #{old_count}"
      puts "    association: #{new_count}"
      puts "    Match: #{tags_match ? '✅' : '❌'}"
      puts "\n  Title tags:"
      puts "    tagged_with: #{old_title_count}"
      puts "    association: #{new_title_count}"
      puts "    Match: #{title_tags_match ? '✅' : '❌'}"
    end
  rescue => e
    puts "❌ ERROR: #{e.message}"
  end
end
```

### Step 1.7: Create Feature Flag (15 minutes)

Create file: `config/initializers/feature_flags.rb`

```ruby
# frozen_string_literal: true

# Feature flags for gradual rollout
FEATURE_FLAGS = {
  # Use direct Entry-Topic associations instead of acts_as_taggable_on
  # Set via ENV: USE_DIRECT_ENTRY_TOPICS=true
  use_direct_entry_topics: ENV.fetch('USE_DIRECT_ENTRY_TOPICS', 'false') == 'true'
}.freeze

# Log feature flags on startup
Rails.logger.info "Feature Flags: #{FEATURE_FLAGS.inspect}"
```

### Step 1.8: Deploy to Staging (1 hour)

```bash
# 1. Commit changes
git add .
git commit -m "Add Entry-Topic direct associations

- Create entry_topics and entry_title_topics tables
- Add associations to Entry and Topic models
- Add auto-sync callbacks for new entries
- Create BackfillEntryTopicsJob
- Add validation rake tasks
- Add feature flag for gradual rollout

Ref: Performance optimization Phase 1"

# 2. Push to staging
git push staging main

# 3. SSH to staging server
ssh user@staging-server

# 4. Run migrations
cd /path/to/app
bundle exec rails db:migrate RAILS_ENV=staging

# 5. Verify tables
bundle exec rails dbconsole -e staging
> SHOW TABLES LIKE '%entry%topic%';
> SELECT COUNT(*) FROM entry_topics;  -- Should be 0
> exit

# 6. Restart app
sudo systemctl restart morfeo-staging
# or: touch tmp/restart.txt
```

### Step 1.9: Run Backfill on Staging (30 minutes)

```bash
# On staging server
cd /path/to/app

# Start backfill job
bundle exec rails runner "BackfillEntryTopicsJob.perform_now(batch_size: 500)" RAILS_ENV=staging

# Monitor progress
tail -f log/staging.log | grep -E "(Backfill|Entry)"

# After completion, verify counts
bundle exec rails console -e staging
```

In staging console:

```ruby
# Check table sizes
puts "Entries: #{Entry.count}"
puts "Topics: #{Topic.count}"
puts "EntryTopics: #{EntryTopic.count}"
puts "EntryTitleTopics: #{EntryTitleTopic.count}"

# Run validation
system("bundle exec rake entry_topics:validate")

# Test a specific topic
topic = Topic.first
system("bundle exec rake entry_topics:validate_topic[#{topic.id}]")
system("bundle exec rake entry_topics:benchmark[#{topic.id}]")
```

### Step 1.10: Validation Checkpoint ✅

**Before proceeding to Week 2, verify:**

- [ ] All migrations ran successfully
- [ ] `entry_topics` and `entry_title_topics` tables exist with proper indexes
- [ ] Models have correct associations
- [ ] Backfill job completed without errors
- [ ] Validation script shows 100% match for all topics
- [ ] Benchmark shows significant performance improvement (>50%)
- [ ] New entries auto-sync (create a test entry and verify)
- [ ] No errors in staging logs

**If any validation fails, DO NOT proceed to production!**

---

## Phase 2: Week 2 - Production Backfill

**Duration:** 2-4 hours (mostly hands-off)  
**Goal:** Deploy to production, run backfill, validate data

### Step 2.1: Pre-Deployment Checklist

- [ ] Staging has been stable for 1 week
- [ ] All validations pass on staging
- [ ] Team has reviewed the changes
- [ ] Rollback plan is documented
- [ ] Deployment window scheduled (off-peak hours)
- [ ] Monitoring tools ready (DataDog, New Relic, etc.)

### Step 2.2: Deploy to Production (30 minutes)

```bash
# 1. Final review
git log --oneline -5
git diff production/main main

# 2. Deploy
git push production main

# 3. SSH to production
ssh user@production-server

# 4. Backup database (safety measure)
cd /path/to/app
bundle exec rails runner "
  system('mysqldump -u root -p morfeo_production > /backups/pre_entry_topics_$(date +%Y%m%d).sql')
" RAILS_ENV=production

# 5. Run migrations
bundle exec rails db:migrate RAILS_ENV=production

# 6. Verify tables exist
bundle exec rails dbconsole -e production
> SHOW TABLES LIKE '%entry%topic%';
> DESCRIBE entry_topics;
> DESCRIBE entry_title_topics;
> SELECT COUNT(*) FROM entry_topics;  -- Should be 0
> exit

# 7. Restart app
sudo systemctl restart morfeo-production
# or: touch tmp/restart.txt

# 8. Check app is healthy
curl -I https://yourdomain.com/health  # or whatever health check endpoint
```

### Step 2.3: Test Auto-Sync for New Entries (15 minutes)

```ruby
# In production console
bundle exec rails console -e production

# Create a test entry
test_entry = Entry.create!(
  site: Site.first,
  url: "https://test.com/test-#{Time.now.to_i}",
  title: "Test Entry for Auto-Sync",
  published_at: Time.current,
  enabled: true
)

# Add tags
test_entry.tag_list.add("Santiago Peña", "ANR")
test_entry.save!

# Verify auto-sync worked
puts "Topics synced: #{test_entry.topics.count}"
test_entry.topics.each { |t| puts "  - #{t.name}" }

# Expected: Should have synced to topics that have those tags
# If this works, new entries will auto-sync during backfill period

# Clean up test
test_entry.destroy
```

### Step 2.4: Run Production Backfill (2-4 hours)

**Option A: All at once (recommended for off-hours)**

```bash
# On production server
cd /path/to/app

# Start backfill in background with logging
nohup bundle exec rails runner "
  result = BackfillEntryTopicsJob.perform_now(batch_size: 500)
  puts result.inspect
" RAILS_ENV=production > log/backfill_$(date +%Y%m%d_%H%M%S).log 2>&1 &

# Get process ID
echo $!

# Monitor progress
tail -f log/backfill_*.log
```

**Option B: In chunks (safer, can pause/resume)**

```ruby
# In production console
# Process first 100K entries
BackfillEntryTopicsJob.perform_now(batch_size: 500, start_id: 1, end_id: 100000)

# Check results, then continue
BackfillEntryTopicsJob.perform_now(batch_size: 500, start_id: 100001, end_id: 200000)

# etc...
```

**Option C: Via Sidekiq (if you have background workers)**

```ruby
# In production console
BackfillEntryTopicsJob.perform_later(batch_size: 500)

# Monitor via Sidekiq dashboard
# https://yourdomain.com/sidekiq
```

### Step 2.5: Monitor Backfill Progress (ongoing)

```bash
# Watch log file
tail -f log/production.log | grep -E "(Backfill|Entry.*Synced)"

# In another terminal, monitor database growth
watch -n 10 'mysql -u root -p -e "
  SELECT 
    (SELECT COUNT(*) FROM morfeo_production.entry_topics) as entry_topics,
    (SELECT COUNT(*) FROM morfeo_production.entry_title_topics) as entry_title_topics;
"'

# Monitor server resources
htop
# or
iostat -x 5
```

**Expected:**
- Entry rate: ~50-100 entries/second
- Duration: 2-4 hours for 1.7M entries
- Database growth: ~200K rows in entry_topics, ~50K in entry_title_topics
- CPU: Moderate (30-50%)
- I/O: Moderate

### Step 2.6: Post-Backfill Validation (30 minutes)

After backfill completes:

```bash
# Run validation rake task
bundle exec rake entry_topics:validate RAILS_ENV=production

# Check for errors
grep -i error log/backfill_*.log

# Verify row counts
bundle exec rails console -e production
```

In console:

```ruby
# Database statistics
puts "=" * 80
puts "Backfill Statistics"
puts "=" * 80
puts "Total Entries: #{Entry.count}"
puts "EntryTopics: #{EntryTopic.count}"
puts "EntryTitleTopics: #{EntryTitleTopic.count}"
puts "Topics: #{Topic.count}"

# Validate a few random topics
Topic.active.sample(5).each do |topic|
  old_count = Entry.enabled.tagged_with(topic.tag_names, any: true).count
  new_count = topic.entries.enabled.count
  match = old_count == new_count ? "✅" : "❌"
  puts "#{match} #{topic.name}: #{old_count} vs #{new_count}"
end

# Check for entries with no topics (might be OK if they have no matching tags)
orphaned = Entry.where.not(id: EntryTopic.select(:entry_id)).where.not(id: EntryTitleTopic.select(:entry_id)).count
puts "\nEntries with no topic associations: #{orphaned}"
puts "(This is OK if these entries don't have tags matching any topic)"
```

### Step 2.7: Validation Checkpoint ✅

**Before proceeding to Week 3, verify:**

- [ ] Backfill completed successfully (check log file)
- [ ] Row counts look correct (EntryTopics: ~200K, EntryTitleTopics: ~50K)
- [ ] Validation script shows 100% match for all active topics
- [ ] No errors in production logs
- [ ] New entries still auto-syncing (test by creating an entry)
- [ ] App performance unchanged (still using old query methods)
- [ ] No customer complaints
- [ ] Database size increase is acceptable (~6.5MB)

**Current state:**
- ✅ New associations exist and are populated
- ✅ Old query methods still work (using ES or tagged_with)
- ✅ New entries auto-sync to both systems
- ✅ No user-facing changes yet

---

## Phase 3: Week 3 - Parallel Testing

**Duration:** 4 hours (implementation) + 1 week (monitoring)  
**Goal:** Test new query methods in production with feature flag

### Step 3.1: Update Topic Model with Feature Flag (2 hours)

Edit: `app/models/topic.rb`

Add these updated methods (replace existing ones):

```ruby
class Topic < ApplicationRecord
  # ... existing associations ...
  
  # UPDATED: list_entries with feature flag
  def list_entries
    cache_key = "topic_#{id}_list_entries#{FEATURE_FLAGS[:use_direct_entry_topics] ? '_v2' : ''}"
    
    Rails.cache.fetch(cache_key, expires_in: 30.minutes) do
      if FEATURE_FLAGS[:use_direct_entry_topics]
        # NEW: Direct association (faster!)
        entries.enabled
               .where(published_at: default_date_range[:gte]..default_date_range[:lte])
               .order(published_at: :desc)
               .includes(:site, :tags)
      else
        # OLD: Elasticsearch
        result = Entry.search(
          where: {
            published_at: default_date_range,
            tags: { in: tag_names }
          },
          order: { published_at: :desc },
          fields: ['id'],
          load: false
        )
        Entry.where(id: result.map(&:id)).includes(:site, :tags).joins(:site)
      end
    end
  end
  
  # UPDATED: title_list_entries with feature flag
  def title_list_entries
    cache_key = "topic_#{id}_title_list_entries#{FEATURE_FLAGS[:use_direct_entry_topics] ? '_v2' : ''}"
    
    Rails.cache.fetch(cache_key, expires_in: 30.minutes) do
      if FEATURE_FLAGS[:use_direct_entry_topics]
        # NEW: Direct association
        title_entries.enabled
                     .where(published_at: default_date_range[:gte]..default_date_range[:lte])
                     .order(published_at: :desc)
                     .includes(:site, :tags)
      else
        # OLD: Elasticsearch
        result = Entry.search(
          where: {
            published_at: default_date_range,
            title_tags: { in: tag_names }
          },
          order: { published_at: :desc },
          fields: ['id']
        )
        Entry.where(id: result.map(&:id)).enabled.order(published_at: :desc).joins(:site)
      end
    end
  end
  
  # UPDATED: report_entries with feature flag
  def report_entries(start_date, end_date)
    if FEATURE_FLAGS[:use_direct_entry_topics]
      # NEW: Direct association
      entries.enabled
             .where(published_at: start_date.beginning_of_day..end_date.end_of_day)
             .order(total_count: :desc)
             .joins(:site)
    else
      # OLD: Elasticsearch
      result = Entry.search(
        where: {
          published_at: { gte: start_date.beginning_of_day, lte: end_date.end_of_day },
          tags: { in: tag_names }
        },
        fields: ['id']
      )
      Entry.where(id: result.map(&:id)).enabled.order(total_count: :desc).joins(:site)
    end
  end
  
  # UPDATED: report_title_entries with feature flag
  def report_title_entries(start_date, end_date)
    if FEATURE_FLAGS[:use_direct_entry_topics]
      # NEW: Direct association
      title_entries.enabled
                   .where(published_at: start_date.beginning_of_day..end_date.end_of_day)
                   .order(total_count: :desc)
                   .joins(:site)
    else
      # OLD: Elasticsearch
      result = Entry.search(
        where: {
          published_at: { gte: start_date.beginning_of_day, lte: end_date.end_of_day },
          title_tags: { in: tag_names }
        },
        fields: ['id']
      )
      Entry.where(id: result.map(&:id)).enabled.order(total_count: :desc).joins(:site)
    end
  end
  
  # UPDATED: chart_entries with feature flag
  def chart_entries(date)
    cache_key = "topic_#{id}_chart_entries_#{date.to_date}#{FEATURE_FLAGS[:use_direct_entry_topics] ? '_v2' : ''}"
    
    Rails.cache.fetch(cache_key, expires_in: 30.minutes) do
      if FEATURE_FLAGS[:use_direct_entry_topics]
        # NEW: Direct association
        entries.enabled
               .where(published_at: date.beginning_of_day..date.end_of_day)
               .order(total_count: :desc)
               .joins(:site)
      else
        # OLD: Elasticsearch
        result = Entry.search(
          where: {
            published_at: { gte: date.beginning_of_day, lte: date.end_of_day },
            tags: { in: tag_names }
          },
          fields: [:id],
          load: false
        )
        Entry.where(id: result.map(&:id)).enabled.order(total_count: :desc).joins(:site)
      end
    end
  end
  
  # UPDATED: title_chart_entries with feature flag
  def title_chart_entries(date)
    cache_key = "topic_#{id}_title_chart_entries_#{date.to_date}#{FEATURE_FLAGS[:use_direct_entry_topics] ? '_v2' : ''}"
    
    Rails.cache.fetch(cache_key, expires_in: 30.minutes) do
      if FEATURE_FLAGS[:use_direct_entry_topics]
        # NEW: Direct association
        title_entries.enabled
                     .where(published_at: date.beginning_of_day..date.end_of_day)
                     .order(total_count: :desc)
                     .joins(:site)
      else
        # OLD: Elasticsearch
        result = Entry.search(
          where: {
            published_at: { gte: date.beginning_of_day, lte: date.end_of_day },
            title_tags: { in: tag_names }
          },
          fields: [:id],
          load: false
        )
        Entry.where(id: result.map(&:id)).enabled.order(total_count: :desc).joins(:site)
      end
    end
  end
  
  # UPDATED: all_list_entries with feature flag
  def all_list_entries
    cache_key = "topic_#{id}_all_list_entries#{FEATURE_FLAGS[:use_direct_entry_topics] ? '_v2' : ''}"
    
    Rails.cache.fetch(cache_key, expires_in: 30.minutes) do
      if FEATURE_FLAGS[:use_direct_entry_topics]
        # NEW: All entries (no tag filtering)
        Entry.enabled
             .where(published_at: default_date_range[:gte]..default_date_range[:lte])
             .order(published_at: :desc)
             .joins(:site)
      else
        # OLD: Elasticsearch
        result = Entry.search(
          where: {
            published_at: default_date_range
          },
          order: { published_at: :desc },
          fields: ['id'],
          load: false
        )
        Entry.where(id: result.map(&:id)).joins(:site)
      end
    end
  end
  
  # KEEP: analytics_topic_entries (already using tagged_with, works fine)
  def analytics_topic_entries
    tag_list = tag_names
    Entry.enabled.normal_range.tagged_with(tag_list, any: true).order(total_count: :desc).limit(20)
  end
end
```

### Step 3.2: Deploy Feature-Flagged Code (1 hour)

```bash
# 1. Commit changes
git add app/models/topic.rb
git commit -m "Add feature flag support to Topic query methods

- Add USE_DIRECT_ENTRY_TOPICS feature flag
- Update all topic query methods with dual implementation
- Old code path still default (no behavior change)
- New code path uses direct Entry-Topic associations

Ref: Performance optimization Phase 3"

# 2. Deploy to production
git push production main

# 3. SSH to production and restart
ssh user@production-server
cd /path/to/app
sudo systemctl restart morfeo-production

# 4. Verify feature flag is OFF by default
bundle exec rails console -e production
> puts FEATURE_FLAGS[:use_direct_entry_topics]
# Should print: false
> exit
```

### Step 3.3: Internal Testing with Flag Enabled (1 hour)

```bash
# On production server, enable flag temporarily for testing
export USE_DIRECT_ENTRY_TOPICS=true

# Restart app
sudo systemctl restart morfeo-production

# Or set via environment file
echo "USE_DIRECT_ENTRY_TOPICS=true" >> /etc/morfeo/env
sudo systemctl restart morfeo-production
```

**Test these URLs manually:**
- `/topics/1` - Topic dashboard
- `/general_dashboard/1` - General dashboard
- `/facebook_topic/1` - Facebook dashboard
- All date range filters
- All chart visualizations

**In console, compare query times:**

```ruby
# With flag enabled
topic = Topic.first

# Test list_entries
require 'benchmark'
time = Benchmark.measure { topic.list_entries.to_a }
puts "list_entries: #{(time.real * 1000).round(2)}ms"
# Expected: 50-100ms

# Test report_entries
time = Benchmark.measure { topic.report_entries(7.days.ago, Date.today).to_a }
puts "report_entries: #{(time.real * 1000).round(2)}ms"
# Expected: 50-100ms

# Compare data accuracy
old_count = Entry.enabled.tagged_with(topic.tag_names, any: true).count
new_count = topic.entries.enabled.count
puts "Match: #{old_count == new_count ? '✅' : '❌'} (#{old_count} vs #{new_count})"
```

### Step 3.4: Enable for Production Traffic (Gradual)

**Day 1-2: Internal users only**
```bash
# Enable flag
export USE_DIRECT_ENTRY_TOPICS=true
sudo systemctl restart morfeo-production
```

Monitor:
- Query times in logs
- Error rates
- User reports

**Day 3-4: All users, monitor closely**

Keep flag enabled, watch metrics:

```bash
# Monitor query times
tail -f log/production.log | grep -E "Completed.*topics|Completed.*dashboard"

# Monitor database
mysqladmin -u root -p processlist | grep entry_topics

# Check for errors
tail -f log/production.log | grep ERROR
```

**Day 5-7: Validate performance improvement**

Collect metrics:

```ruby
# In console
# Sample query times across multiple topics
results = []

Topic.active.sample(10).each do |topic|
  require 'benchmark'
  
  time = Benchmark.measure { topic.list_entries.to_a }
  ms = (time.real * 1000).round(2)
  
  results << { topic: topic.name, time_ms: ms }
  puts "#{topic.name}: #{ms}ms"
end

avg = results.sum { |r| r[:time_ms] } / results.size
puts "\nAverage query time: #{avg.round(2)}ms"
puts "Target: <100ms"
puts avg < 100 ? "✅ TARGET MET" : "⚠️  Needs optimization"
```

### Step 3.5: Validation Checkpoint ✅

**After 1 week with feature flag enabled, verify:**

- [ ] Query times are 50-100ms (vs 440ms before)
- [ ] No data mismatches reported
- [ ] Error rates normal (no increase)
- [ ] User experience same or better
- [ ] All dashboards working correctly
- [ ] Cache hit rates normal
- [ ] Database performance good (no slow queries)

**If any metric fails:**
- Disable flag: `export USE_DIRECT_ENTRY_TOPICS=false && restart`
- Investigate issue
- Fix and redeploy
- Retest

**If all metrics pass:** Proceed to Phase 4 (full switchover)

---

## Phase 4: Week 4 - Full Switchover

**Duration:** 4 hours  
**Goal:** Remove feature flags, make new code the default, remove old code

### Step 4.1: Remove Feature Flags (2 hours)

Edit: `app/models/topic.rb`

Remove all conditional logic, keep only the new code:

```ruby
class Topic < ApplicationRecord
  # ... existing associations ...
  
  # FINAL: Direct association (no feature flag)
  def list_entries
    Rails.cache.fetch("topic_#{id}_list_entries_v2", expires_in: 30.minutes) do
      entries.enabled
             .where(published_at: default_date_range[:gte]..default_date_range[:lte])
             .order(published_at: :desc)
             .includes(:site, :tags)
    end
  end
  
  def title_list_entries
    Rails.cache.fetch("topic_#{id}_title_list_entries_v2", expires_in: 30.minutes) do
      title_entries.enabled
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
  
  def report_title_entries(start_date, end_date)
    title_entries.enabled
                 .where(published_at: start_date.beginning_of_day..end_date.end_of_day)
                 .order(total_count: :desc)
                 .joins(:site)
  end
  
  def chart_entries(date)
    cache_key = "topic_#{id}_chart_entries_#{date.to_date}_v2"
    
    Rails.cache.fetch(cache_key, expires_in: 30.minutes) do
      entries.enabled
             .where(published_at: date.beginning_of_day..date.end_of_day)
             .order(total_count: :desc)
             .joins(:site)
    end
  end
  
  def title_chart_entries(date)
    cache_key = "topic_#{id}_title_chart_entries_#{date.to_date}_v2"
    
    Rails.cache.fetch(cache_key, expires_in: 30.minutes) do
      title_entries.enabled
                   .where(published_at: date.beginning_of_day..date.end_of_day)
                   .order(total_count: :desc)
                   .joins(:site)
    end
  end
  
  def all_list_entries
    Rails.cache.fetch("topic_#{id}_all_list_entries_v2", expires_in: 30.minutes) do
      Entry.enabled
           .where(published_at: default_date_range[:gte]..default_date_range[:lte])
           .order(published_at: :desc)
           .joins(:site)
    end
  end
  
  # Keep this - it's already using tagged_with which is fine for small result sets
  def analytics_topic_entries
    tag_list = tag_names
    Entry.enabled.normal_range.tagged_with(tag_list, any: true).order(total_count: :desc).limit(20)
  end
  
  # ... rest of methods ...
end
```

### Step 4.2: Update Tag Model (1 hour)

Edit: `app/models/tag.rb`

Replace the search-based methods:

```ruby
class Tag < ApplicationRecord
  # ... existing associations ...
  
  # UPDATED: Use joins through entry_topics
  def list_entries
    Entry.enabled
         .joins(:entry_topics)
         .joins('INNER JOIN topics ON topics.id = entry_topics.topic_id')
         .joins('INNER JOIN taggings ON taggings.taggable_id = topics.id AND taggings.taggable_type = "Topic"')
         .where('taggings.tag_id = ?', id)
         .where('entries.published_at >= ?', DAYS_RANGE.days.ago)
         .distinct
         .order('entries.published_at DESC')
         .includes(:site, :tags)
  end
  
  # UPDATED: Use joins through entry_title_topics
  def title_list_entries
    Entry.enabled
         .joins(:entry_title_topics)
         .joins('INNER JOIN topics ON topics.id = entry_title_topics.topic_id')
         .joins('INNER JOIN taggings ON taggings.taggable_id = topics.id AND taggings.taggable_type = "Topic"')
         .where('taggings.tag_id = ?', id)
         .where('entries.published_at >= ?', DAYS_RANGE.days.ago)
         .distinct
         .order('entries.published_at DESC')
         .includes(:site, :tags)
  end
  
  # ... rest of model ...
end
```

### Step 4.3: Clear Old Caches (5 minutes)

```ruby
# In production console
# Clear old cache keys (ones without _v2 suffix)
Rails.cache.clear

# Or more targeted:
Topic.find_each do |topic|
  Rails.cache.delete("topic_#{topic.id}_list_entries")
  Rails.cache.delete("topic_#{topic.id}_title_list_entries")
  Rails.cache.delete("topic_#{topic.id}_all_list_entries")
  # etc...
end
```

### Step 4.4: Deploy Final Version (30 minutes)

```bash
# 1. Commit
git add app/models/topic.rb app/models/tag.rb
git commit -m "Remove feature flags - direct associations now default

- Remove all USE_DIRECT_ENTRY_TOPICS conditionals
- Use direct Entry-Topic associations for all queries
- Remove old Elasticsearch query paths
- Update Tag model to use join-based queries

Ref: Performance optimization Phase 4"

# 2. Deploy
git push production main

# 3. SSH and restart
ssh user@production-server
cd /path/to/app
sudo systemctl restart morfeo-production

# 4. Clear cache
bundle exec rails console -e production
> Rails.cache.clear
> exit
```

### Step 4.5: Monitor for 1 Week

**Daily checks:**

```ruby
# In console each day
# Check query performance
require 'benchmark'

topic = Topic.first
time = Benchmark.measure { topic.list_entries.to_a }
puts "Query time: #{(time.real * 1000).round(2)}ms"
puts "Target: <100ms"

# Check for errors
system("grep -i error log/production.log | grep -i entry_topics | tail -20")

# Check database performance
system("mysql -u root -p -e '
  SELECT * FROM information_schema.processlist 
  WHERE info LIKE \"%entry_topics%\" 
  ORDER BY time DESC LIMIT 10;
'")
```

### Step 4.6: Validation Checkpoint ✅

**After 1 week, verify:**

- [ ] All queries using direct associations (no feature flag code)
- [ ] Query times consistently <100ms
- [ ] Error rates normal
- [ ] User satisfaction maintained/improved
- [ ] No slow query alerts
- [ ] Database performance stable
- [ ] Cache hit rates good

**Current state:**
- ✅ All queries use direct Entry-Topic associations
- ✅ 80-88% performance improvement confirmed
- ✅ Elasticsearch still running (but not used)
- ✅ Ready for ES removal

---

## Phase 5: Week 5 - Elasticsearch Cleanup

**Duration:** 2 hours  
**Goal:** Remove Elasticsearch, save 33.6GB RAM

### Step 5.1: Final Verification (30 minutes)

Before removing ES, confirm it's truly not needed:

```bash
# Check if any code still uses Entry.search
grep -r "Entry.search" app/ --include="*.rb"

# Should only find:
# - Commented out code
# - The search_data method (can be removed)

# Check if any code uses searchkick
grep -r "searchkick" app/ --include="*.rb"

# Should only find:
# - Entry model declaration (will remove)
```

### Step 5.2: Remove Searchkick from Models (15 minutes)

Edit: `app/models/entry.rb`

```ruby
class Entry < ApplicationRecord
  # searchkick  # ← REMOVE THIS LINE
  
  acts_as_taggable_on :tags, :title_tags  # Keep this!
  
  # ... rest of model ...
  
  # REMOVE: search_data method (lines ~190-201)
  # def search_data
  #   {
  #     title: title,
  #     description: description,
  #     ...
  #   }
  # end
  
  # ... rest of model ...
end
```

### Step 5.3: Remove Gems (15 minutes)

Edit: `Gemfile`

```ruby
# Find and remove these lines:
# gem 'searchkick'
# gem 'elasticsearch'

# Or comment them out first (safer):
# gem 'searchkick'  # Removed: Using direct associations
# gem 'elasticsearch'  # Removed: No longer needed
```

```bash
# Update bundle
bundle install

# Commit
git add Gemfile Gemfile.lock app/models/entry.rb
git commit -m "Remove Elasticsearch dependencies

- Remove searchkick from Entry model
- Remove search_data method
- Remove searchkick and elasticsearch gems
- All queries now use direct Entry-Topic associations

Ref: Performance optimization Phase 5"
```

### Step 5.4: Deploy Without ES (30 minutes)

```bash
# Deploy
git push production main

# SSH to production
ssh user@production-server
cd /path/to/app

# Update gems
bundle install

# Restart app
sudo systemctl restart morfeo-production

# Verify app is healthy
curl -I https://yourdomain.com/
tail -f log/production.log
```

### Step 5.5: Stop Elasticsearch Service (15 minutes)

**⚠️ WAIT 24-48 HOURS AFTER DEPLOYMENT**

After confirming everything works without ES:

```bash
# On production server
# Stop Elasticsearch
sudo systemctl stop elasticsearch

# Disable auto-start
sudo systemctl disable elasticsearch

# Verify it's stopped
sudo systemctl status elasticsearch

# Check memory usage dropped
free -h
# You should see 33.6GB freed!

# Monitor app continues to work
curl -I https://yourdomain.com/
tail -f /path/to/app/log/production.log
```

### Step 5.6: Monitor for 1 Week

**Daily checks:**

```bash
# 1. App is healthy
curl -I https://yourdomain.com/

# 2. No ES-related errors
grep -i elasticsearch log/production.log

# 3. Query performance still good
# (Use console to test query times as before)

# 4. Memory usage
free -h
# Should be ~33.6GB less than before
```

### Step 5.7: Uninstall Elasticsearch (Optional)

**⚠️ WAIT 1 WEEK AFTER STOPPING SERVICE**

If everything is stable for a week:

```bash
# Backup ES data (just in case)
sudo tar -czf /backups/elasticsearch_data_$(date +%Y%m%d).tar.gz /var/lib/elasticsearch/

# Uninstall
sudo apt-get remove elasticsearch
# or
sudo yum remove elasticsearch

# Remove data directory (after backup!)
sudo rm -rf /var/lib/elasticsearch

# Remove config
sudo rm -rf /etc/elasticsearch
```

### Step 5.8: Final Validation Checkpoint ✅

**After ES removed, verify:**

- [ ] Elasticsearch service stopped
- [ ] Memory freed (~33.6GB)
- [ ] App functioning normally
- [ ] Query times still good (<100ms)
- [ ] No errors in logs
- [ ] All dashboards working
- [ ] Users happy

**Final state:**
- ✅ Elasticsearch removed
- ✅ 33.6GB RAM freed
- ✅ Query performance improved 80-88%
- ✅ Cleaner, simpler architecture
- ✅ Direct Rails associations throughout

---

## Testing & Validation

### Automated Test Suite

Create file: `test/integration/entry_topic_associations_test.rb`

```ruby
require 'test_helper'

class EntryTopicAssociationsTest < ActionDispatch::IntegrationTest
  def setup
    @topic = topics(:honor_colorado)  # Assumes fixtures
    @entry = entries(:test_entry)
  end
  
  test "entry syncs to topics on tag save" do
    @entry.tag_list = ["Santiago Peña", "ANR"]
    @entry.save!
    
    assert @entry.topics.any?, "Entry should have synced to topics"
    assert @entry.topics.include?(@topic), "Entry should be associated with topic"
  end
  
  test "topic.entries returns correct entries" do
    old_count = Entry.enabled.tagged_with(@topic.tag_names, any: true).count
    new_count = @topic.entries.enabled.count
    
    assert_equal old_count, new_count, "Entry counts should match"
  end
  
  test "query performance is acceptable" do
    require 'benchmark'
    
    time = Benchmark.measure { @topic.list_entries.to_a }
    ms = time.real * 1000
    
    assert ms < 100, "Query should complete in under 100ms, was #{ms.round(2)}ms"
  end
end
```

Run tests:

```bash
rails test test/integration/entry_topic_associations_test.rb
```

### Manual Testing Checklist

For each deployment phase, test:

**Topic Dashboards:**
- [ ] `/topics/:id` - Topic show page loads
- [ ] Entry list displays correctly
- [ ] Charts render properly
- [ ] Date range filters work
- [ ] Pagination works

**General Dashboard:**
- [ ] `/general_dashboard/:id` - Loads correctly
- [ ] Multi-channel data aggregates properly
- [ ] Filters work

**Facebook/Twitter Dashboards:**
- [ ] `/facebook_topic/:id` - Works (uses different associations)
- [ ] `/twitter_topic/:id` - Works (uses different associations)

**Reports:**
- [ ] Report generation works
- [ ] CSV exports work
- [ ] PDF exports work

**Admin:**
- [ ] Can create new entries
- [ ] Can edit entries
- [ ] Can add/remove tags
- [ ] Auto-sync triggers

---

## Monitoring & Metrics

### Key Metrics to Track

| Metric | Tool | Target | Alert Threshold |
|--------|------|--------|-----------------|
| Query time (p95) | New Relic/DataDog | <100ms | >200ms |
| Query time (p50) | New Relic/DataDog | <50ms | >100ms |
| Error rate | Monitoring tool | <0.1% | >1% |
| Database CPU | Server monitoring | <50% | >80% |
| Memory usage | Server monitoring | Tracked | N/A |
| User complaints | Support tickets | 0 | >2 per day |

### Monitoring Commands

```bash
# Query performance (from logs)
tail -f log/production.log | grep "Completed.*topics" | awk '{print $(NF-1)}'

# Database queries
mysql -u root -p -e "
SELECT 
  SUBSTRING(sql_text, 1, 100) AS query,
  COUNT_STAR AS executions,
  AVG_TIMER_WAIT / 1000000000 AS avg_ms
FROM performance_schema.events_statements_summary_by_digest
WHERE sql_text LIKE '%entry_topics%'
ORDER BY avg_ms DESC
LIMIT 10;
"

# Memory usage
free -h

# CPU usage
top -bn1 | grep "Cpu(s)"
```

### Dashboard Metrics

Set up in your monitoring tool (DataDog/New Relic/Grafana):

1. **Query Performance Dashboard**
   - Average query time by endpoint
   - P95/P99 query times
   - Slow query count

2. **Database Dashboard**
   - entry_topics table size
   - Index usage
   - Slow queries
   - Connection pool usage

3. **System Resources**
   - Memory usage over time
   - CPU usage
   - Disk I/O

---

## Rollback Procedures

### Level 1: Disable Feature Flag (Week 3 only)

**Symptoms:** Query performance issues, errors

```bash
# On production server
export USE_DIRECT_ENTRY_TOPICS=false
sudo systemctl restart morfeo-production

# Or via env file
sed -i 's/USE_DIRECT_ENTRY_TOPICS=true/USE_DIRECT_ENTRY_TOPICS=false/' /etc/morfeo/env
sudo systemctl restart morfeo-production
```

**Result:** Reverts to old query methods (ES or tagged_with)

### Level 2: Revert Code Deployment

**Symptoms:** Major issues, can't be fixed by flag

```bash
# Find previous good commit
git log --oneline -10

# Revert to previous commit
git revert HEAD

# Or reset to specific commit
git reset --hard abc123  # Use actual commit hash

# Deploy
git push production main --force  # ⚠️ Force push required after reset

# SSH and restart
ssh user@production-server
cd /path/to/app
git pull
bundle install
sudo systemctl restart morfeo-production
```

**Result:** Code reverted, old behavior restored

### Level 3: Restart Elasticsearch

**Symptoms:** Performance degraded, need ES back temporarily

```bash
# On production server
sudo systemctl start elasticsearch
sudo systemctl enable elasticsearch

# Verify it's running
sudo systemctl status elasticsearch

# Check health
curl -XGET 'localhost:9200/_cluster/health?pretty'
```

**If ES index is missing (was deleted):**

```bash
# Reindex entries
bundle exec rails console -e production
> Entry.reindex
# This may take hours for 1.7M entries!
```

**Result:** Elasticsearch running again, can revert code to use it

### Level 4: Full Rollback

**Symptoms:** Complete failure, need to undo everything

```bash
# 1. Restart Elasticsearch
sudo systemctl start elasticsearch

# 2. Revert code to before migration
git reset --hard <commit-before-migration>
git push production main --force

# 3. Deploy and restart
cd /path/to/app
git pull --force
bundle install
sudo systemctl restart morfeo-production

# 4. (Optional) Drop new tables
bundle exec rails dbconsole -e production
> DROP TABLE entry_topics;
> DROP TABLE entry_title_topics;
> exit
```

**Result:** Complete rollback, system as it was before migration

---

## Appendix: All Code Files

### A1: Complete Entry Model

```ruby
# app/models/entry.rb
# frozen_string_literal: true

class Entry < ApplicationRecord
  # Tagging (keep this!)
  acts_as_taggable_on :tags, :title_tags
  
  # Existing associations
  belongs_to :site, touch: true
  has_many :comments, dependent: :destroy
  has_one :twitter_post, dependent: :nullify
  
  # NEW: Direct topic associations
  has_many :entry_topics, dependent: :destroy
  has_many :topics, through: :entry_topics
  
  has_many :entry_title_topics, dependent: :destroy
  has_many :title_topics, through: :entry_title_topics, source: :topic
  
  # Validations
  validates :url, uniqueness: true
  
  # Aliases
  alias_attribute :habilitar_Deshabilitar_Notas, :enabled
  alias_attribute :notas_Repetidas, :repeated
  
  # Enums
  attribute :repeateds, :integer
  enum :repeateds, { No: 0, Si: 1, Limpiado: 2 }
  
  # Scopes
  scope :enabled, -> { where(enabled: true) }
  scope :normal_range, -> { where(published_at: DAYS_RANGE.days.ago..) }
  scope :has_interactions, -> { where('total_count >= ?', 10) }
  scope :positive, -> { where(polarity: :positive) }
  scope :negative, -> { where(polarity: :negative) }
  scope :neutral, -> { where(polarity: :neutral) }
  
  # NEW: Scoped queries
  scope :for_topic, ->(topic) {
    topic_id = topic.is_a?(Topic) ? topic.id : topic
    joins(:entry_topics).where(entry_topics: { topic_id: topic_id })
  }
  
  scope :for_topic_title, ->(topic) {
    topic_id = topic.is_a?(Topic) ? topic.id : topic
    joins(:entry_title_topics).where(entry_title_topics: { topic_id: topic_id })
  }
  
  # Callbacks
  after_save :sync_topics_from_tags, if: :saved_change_to_tag_list?
  after_save :sync_title_topics_from_tags, if: :saved_change_to_title_tag_list?
  
  # ... rest of your existing Entry methods ...
  
  private
  
  def sync_topics_from_tags
    return if tag_list.empty?
    
    matching_topics = Topic.joins(:tags)
                          .where(tags: { name: tag_list })
                          .distinct
    
    self.topics = matching_topics
    Rails.logger.info "Entry #{id}: Synced #{matching_topics.count} topics from tags"
  rescue => e
    Rails.logger.error "Entry #{id}: Failed to sync topics - #{e.message}"
  end
  
  def sync_title_topics_from_tags
    return if title_tag_list.empty?
    
    matching_topics = Topic.joins(:tags)
                          .where(tags: { name: title_tag_list })
                          .distinct
    
    self.title_topics = matching_topics
    Rails.logger.info "Entry #{id}: Synced #{matching_topics.count} title topics from tags"
  rescue => e
    Rails.logger.error "Entry #{id}: Failed to sync title topics - #{e.message}"
  end
end
```

### A2: Complete Topic Model (Final Version)

```ruby
# app/models/topic.rb
# frozen_string_literal: true

require 'digest'

class Topic < ApplicationRecord
  # Existing
  has_paper_trail on: %i[create destroy update]
  has_many :topic_stat_dailies, dependent: :destroy
  has_many :title_topic_stat_dailies, dependent: :destroy
  has_many :user_topics, dependent: :destroy
  has_many :users, through: :user_topics
  has_many :reports, dependent: :destroy
  has_many :templates, dependent: :destroy
  has_and_belongs_to_many :tags
  accepts_nested_attributes_for :tags
  
  # NEW: Direct entry associations
  has_many :entry_topics, dependent: :destroy
  has_many :entries, through: :entry_topics
  
  has_many :entry_title_topics, dependent: :destroy
  has_many :title_entries, through: :entry_title_topics, source: :entry
  
  # Callbacks
  before_update :remove_words_spaces
  
  # Scopes
  scope :active, -> { where(status: true) }
  
  # Methods
  def tag_names
    @tag_names ||= tags.map(&:name)
  end
  
  def default_date_range
    { gte: DAYS_RANGE.days.ago.beginning_of_day, lte: Date.today.end_of_day }
  end
  
  # OPTIMIZED: Query methods using direct associations
  def list_entries
    Rails.cache.fetch("topic_#{id}_list_entries_v2", expires_in: 30.minutes) do
      entries.enabled
             .where(published_at: default_date_range[:gte]..default_date_range[:lte])
             .order(published_at: :desc)
             .includes(:site, :tags)
    end
  end
  
  def title_list_entries
    Rails.cache.fetch("topic_#{id}_title_list_entries_v2", expires_in: 30.minutes) do
      title_entries.enabled
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
  
  def report_title_entries(start_date, end_date)
    title_entries.enabled
                 .where(published_at: start_date.beginning_of_day..end_date.end_of_day)
                 .order(total_count: :desc)
                 .joins(:site)
  end
  
  def chart_entries(date)
    cache_key = "topic_#{id}_chart_entries_#{date.to_date}_v2"
    
    Rails.cache.fetch(cache_key, expires_in: 30.minutes) do
      entries.enabled
             .where(published_at: date.beginning_of_day..date.end_of_day)
             .order(total_count: :desc)
             .joins(:site)
    end
  end
  
  def title_chart_entries(date)
    cache_key = "topic_#{id}_title_chart_entries_#{date.to_date}_v2"
    
    Rails.cache.fetch(cache_key, expires_in: 30.minutes) do
      title_entries.enabled
                   .where(published_at: date.beginning_of_day..date.end_of_day)
                   .order(total_count: :desc)
                   .joins(:site)
    end
  end
  
  def all_list_entries
    Rails.cache.fetch("topic_#{id}_all_list_entries_v2", expires_in: 30.minutes) do
      Entry.enabled
           .where(published_at: default_date_range[:gte]..default_date_range[:lte])
           .order(published_at: :desc)
           .joins(:site)
    end
  end
  
  def analytics_topic_entries
    tag_list = tag_names
    Entry.enabled.normal_range.tagged_with(tag_list, any: true).order(total_count: :desc).limit(20)
  end
  
  def all_tagged_entries
    Entry.where(id: entries.pluck(:id) + title_entries.pluck(:id)).distinct
  end
  
  # ... rest of your existing Topic methods ...
  
  private
  
  def remove_words_spaces
    # ... your existing implementation ...
  end
end
```

---

## Summary

### Total Timeline: 5 Weeks

| Week | Phase | Effort | Status |
|------|-------|--------|--------|
| 1 | Infrastructure Setup | 8 hours | Migrations, models, jobs |
| 2 | Production Backfill | 2-4 hours | Automated backfill |
| 3 | Parallel Testing | 4 hours + monitoring | Feature flag testing |
| 4 | Full Switchover | 4 hours | Remove flags, finalize |
| 5 | ES Cleanup | 2 hours | Remove Elasticsearch |

**Total effort:** 30-35 hours spread over 5 weeks

### Expected Outcomes

- ✅ **Performance:** 440ms → 50-100ms (80-88% improvement)
- ✅ **Memory:** Save 33.6GB RAM
- ✅ **Architecture:** Cleaner, simpler Rails code
- ✅ **Scalability:** Better prepared for future growth
- ✅ **Maintainability:** Direct associations, no external dependencies

### Success Criteria

- [ ] All queries complete in <100ms
- [ ] Data accuracy 100% (validated at each phase)
- [ ] Zero downtime deployment
- [ ] Elasticsearch removed
- [ ] 33.6GB RAM freed
- [ ] No user complaints
- [ ] Code cleaner and more maintainable

---

**Ready to begin implementation? Start with Phase 1, Week 1!**


---
type: concept
title: Background Jobs
description: ActiveJob-based background processing for crawling, sentiment analysis, and data synchronization
tags:
  - architecture
  - jobs
  - activejob
  - background-processing
  - async
---

# Background Jobs

Morfeo uses ActiveJob for background processing. Jobs handle long-running tasks like crawling, sentiment analysis, and data synchronization.

## Architecture

```
ApplicationJob (base)
├── SyncTopicEntriesJob
├── SetEntrySentimentJob
├── ExtractBasicDataJob
├── UpdateDatesJob
├── UpdateEntryFacebookStatsJob
├── BackfillEntryTopicsJob
└── Tags Jobs
    ├── TagEntriesJob
    ├── UntagEntriesJob
    └── UpdateTagEntriesJob
```

## Base Job: ApplicationJob

**File:** `app/jobs/application_job.rb`

Standard ActiveJob base class with default configuration.

## Core Jobs

### SyncTopicEntriesJob

**File:** `app/jobs/sync_topic_entries_job.rb`

Synchronizes entries with topics based on tag matching.

**Parameters:**

- `topic_id` - Topic to sync
- `days` - Lookback period (default: 60 days)

**Process:**

1. Find topic and its tags
2. Query entries matching topic tags within date range
3. Sync each entry's topic associations via `entry.sync_topics_from_tags`
4. Log results (synced, errors)

**Usage:** Called by scheduled tasks to keep topic-entry relationships current.

### SetEntrySentimentJob

**File:** `app/jobs/set_entry_sentiment_job.rb`

Sets polarity (sentiment) for entries.

**Parameters:**

- `entry_id` - Entry to analyze

**Features:**

- Retry with exponential backoff (3 attempts)
- Only processes entries belonging to topics
- Calls `entry.set_polarity(force: false)`

**Usage:** Enqueued when new entries are created or when sentiment needs updating.

### ExtractBasicDataJob

**File:** `app/jobs/extract_basic_data_job.rb`

Extracts basic information from web pages.

**Parameters:**

- `entry_id` - Entry to process
- `page` - Page content/URL

**Process:** Delegates to `WebExtractorServices::ExtractBasicInfo.call(entry_id, page)`

### UpdateDatesJob

**File:** `app/jobs/update_dates_job.rb`

Updates publication dates for entries by re-parsing the source page.

**Parameters:**

- `entry_id` - Entry to update

**Process:**

1. Fetch entry URL
2. Parse HTML with Nokogiri
3. Extract date via `WebExtractorServices::ExtractDate.call(doc)`
4. Update entry if successful

### UpdateEntryFacebookStatsJob

**File:** `app/jobs/update_entry_facebook_stats_job.rb`

Updates Facebook engagement statistics for entries.

**Parameters:**

- `entry_id` - Entry to update

**Features:**

- Retry with exponential backoff (3 attempts) for API rate limiting
- Calls `FacebookServices::UpdateStats.call(entry_id)`
- Updates entry with new stats on success

### BackfillEntryTopicsJob

**File:** `app/jobs/backfill_entry_topics_job.rb`

Bulk backfill of entry-topic relationships.

**Parameters:**

- `batch_size` - Entries per batch (default: 500)
- `start_id` - Optional start ID
- `end_id` - Optional end ID

**Features:**

- Processes entries in batches with throttling (50ms sleep)
- Progress logging every 100 entries
- Rate and ETA calculation
- Comprehensive error reporting
- Syncs both tag and title tag associations

## Tags Jobs

### TagEntriesJob

**File:** `app/jobs/tags/tag_entries_job.rb`

Tags entries based on content analysis.

### UntagEntriesJob

**File:** `app/jobs/tags/untag_entries_job.rb`

Removes tags from entries.

### UpdateTagEntriesJob

**File:** `app/jobs/tags/update_tag_entries_job.rb`

Updates tag associations for entries.

## Job Configuration

All jobs use the default queue:

```ruby
queue_as :default
```

## Error Handling Patterns

### Retry with Backoff

```ruby
retry_on StandardError, wait: :exponentially_longer, attempts: 3
```

Used by: `SetEntrySentimentJob`, `UpdateEntryFacebookStatsJob`

### Graceful Degradation

```ruby
rescue ActiveRecord::RecordNotFound
  Rails.logger.warn "Entry #{entry_id} not found, skipping"
rescue StandardError => e
  Rails.logger.error "Failed for Entry #{entry_id}: #{e.message}"
  raise # Re-raise to trigger retry
end
```

### Batch Processing with Error Collection

```ruby
errors = []
query.find_in_batches(batch_size: batch_size) do |batch|
  batch.each do |entry|
    begin
      # Process entry
    rescue => e
      errors << { entry_id: entry.id, error: e.message }
    end
  end
end
```

Used by: `BackfillEntryTopicsJob`

## Related Concepts

- [Scheduled Tasks](scheduled_tasks.md) - Cron jobs that enqueue these background jobs
- [Web Extractor Services](services.md) - Services called by extraction jobs
- [Facebook Services](services.md) - Services called by Facebook jobs
- [Business Rules](business_rules/) - Rules governing job behavior

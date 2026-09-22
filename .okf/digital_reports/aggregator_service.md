---
type: Service
title: Digital Aggregator Service
description: Main data aggregation service for digital media topic analytics
resource: app/services/digital_dashboard_services/aggregator_service.rb
tags: [digital, reports, service, aggregation, entries]
timestamp: 2026-09-22T00:00:00Z
---

# Overview

The AggregatorService is the central data aggregation service for digital media topic analytics. It orchestrates data loading from multiple sources and returns a comprehensive dashboard data structure.

# Interface

```ruby
DigitalDashboardServices::AggregatorService.call(
  topic: topic,
  days_range: 7
)
```

# Return Structure

Returns a hash with the following keys:

- `topic_data` - Core topic analytics data
  - `tag_list` - Topic tag names
  - `entries` - Filtered entries
  - `total_entries` - Total entry count
  - `total_interactions` - Sum of all engagement
  - `positive_count` - Positive sentiment entries
  - `negative_count` - Negative sentiment entries
  - `neutral_count` - Neutral sentiment entries

- `chart_data` - Chart data for visualizations
  - `chart_entries` - Daily entry counts
  - `chart_interactions` - Daily interaction totals
  - `chart_positive` - Daily positive sentiment counts
  - `chart_negative` - Daily negative sentiment counts
  - `chart_neutral` - Daily neutral sentiment counts

- `percentages` - Percentage breakdowns
  - `positive_percentage` - Positive sentiment percentage
  - `negative_percentage` - Negative sentiment percentage
  - `neutral_percentage` - Neutral sentiment percentage

- `tags_and_words` - Tag and word frequency data
  - `tag_counts` - Tag distribution
  - `tag_interactions` - Tag interaction breakdown
  - `word_occurrences` - Word frequency hash
  - `bigram_occurrences` - Bigram frequency hash
  - `positive_words` - Positive sentiment words
  - `negative_words` - Negative sentiment words

- `temporal_intelligence` - Time-based insights
  - `temporal_summary` - Summary text
  - `optimal_time` - Best posting time
  - `trend_velocity` - Trend direction and speed
  - `engagement_velocity` - Engagement trend
  - `content_half_life` - Content decay rate
  - `peak_hours` - Peak posting hours
  - `peak_days` - Peak posting days
  - `heatmap_data` - Heatmap visualization data

- `viral_content` - Viral content analysis

# Data Sources

- `Entry` model for article data
- `Topic` model for tag filtering
- `Site` model for site metadata
- Groupdate gem for temporal aggregation
- TextMood for sentiment analysis

# Key Features

- Sentiment analysis integration (unique to digital reports)
- Calendar view data preparation
- Advanced filtering by polarity
- Title vs content tag analysis

# Related

- [TopicController](controller.md) - Uses this service for data loading
- [Digital Topic Views](views.md) - Consumes the aggregated data
- [Entry Model](../models/entry.md) - Primary data source
- [Topic Model](../models/topic.md) - Topic entity

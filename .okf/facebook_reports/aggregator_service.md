---
type: Service
title: Facebook Aggregator Service
description: Main data aggregation service for Facebook topic analytics
resource: app/services/facebook_dashboard_services/aggregator_service.rb
tags: [facebook, reports, service, aggregation]
timestamp: 2026-09-22T00:00:00Z
---

# Overview

The AggregatorService is the central data aggregation service for Facebook topic analytics. It orchestrates data loading from multiple sources and returns a comprehensive dashboard data structure.

# Interface

```ruby
FacebookDashboardServices::AggregatorService.call(
  topic: topic,
  top_posts_limit: 20,
  days_range: 7
)
```

# Return Structure

Returns a hash with the following keys:

- `facebook_data` - Core Facebook analytics data
  - `tag_list` - Topic tag names
  - `entries` - Filtered Facebook posts
  - `chart_posts` - Daily post counts for charts
  - `chart_interactions` - Daily interaction totals
  - `total_posts` - Total post count
  - `total_interactions` - Sum of all engagement
  - `total_views` - Sum of estimated views
  - `average_interactions` - Mean interactions per post
  - `top_posts` - Top performing posts
  - `word_occurrences` - Word frequency hash
  - `bigram_occurrences` - Bigram frequency hash
  - `tag_counts` - Tag distribution
  - `tag_interactions` - Tag interaction breakdown
  - `positive_words` - Positive sentiment words
  - `negative_words` - Negative sentiment words

- `pages_data` - Page-level analytics
  - `pages_count` - Posts by page
  - `pages_interactions` - Interactions by page
  - `site_top_counts` - Top sites by post count
  - `site_counts` - Site post counts
  - `site_sums` - Site interaction sums

- `temporal_intelligence` - Time-based insights
  - `temporal_summary` - Summary text
  - `optimal_time` - Best posting time
  - `trend_velocity` - Trend direction and speed
  - `engagement_velocity` - Engagement trend
  - `content_half_life` - Content decay rate
  - `peak_hours` - Peak posting hours
  - `peak_days` - Peak posting days
  - `heatmap_data` - Heatmap visualization data

- `sentiment_analysis` - Sentiment metrics
  - `sentiment_summary` - Summary text
  - `sentiment_distribution` - Positive/negative/neutral breakdown
  - `sentiment_over_time` - Temporal sentiment trend
  - `reaction_breakdown` - Individual reaction counts
  - `top_positive_posts` - Most positive posts
  - `top_negative_posts` - Most negative posts
  - `controversial_posts` - High controversy posts
  - `emotional_trends` - Emotional intensity trends
  - `sentiment_trend` - Overall sentiment direction

- `viral_content` - Viral post analysis

# Data Sources

- `FacebookEntry` model for post data
- `Page` model for page metadata
- `Topic` model for tag filtering
- Groupdate gem for temporal aggregation
- Custom sentiment analysis algorithms

# Performance

- The service passes its already-loaded topic tag names to `FacebookEntry.for_topic`, avoiding a second tag lookup for the primary dashboard scope.
- Word and bigram frequencies are produced together from one traversal of the filtered posts.

# Related

- [FacebookTopicController](controller.md) - Uses this service for data loading
- [Facebook Topic Views](views.md) - Consumes the aggregated data
- [FacebookEntry Model](../models/facebook_entry.md) - Primary data source
- [Page Model](../models/page.md) - Page metadata source

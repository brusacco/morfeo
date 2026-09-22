---
type: Service
title: Instagram Aggregator Service
description: Main data aggregation service for Instagram topic analytics
resource: app/services/instagram_dashboard_services/aggregator_service.rb
tags: [instagram, reports, service, aggregation]
timestamp: 2026-09-22T00:00:00Z
---

# Overview

The AggregatorService is the central data aggregation service for Instagram topic analytics. It orchestrates data loading from multiple sources and returns a comprehensive dashboard data structure.

# Interface

```ruby
InstagramDashboardServices::AggregatorService.call(
  topic: topic,
  top_posts_limit: 20,
  days_range: 7
)
```

# Return Structure

Returns a hash with the following keys:

- `instagram_data` - Core Instagram analytics data
  - `tag_list` - Topic tag names
  - `posts` - Filtered Instagram posts
  - `chart_posts` - Daily post counts for charts
  - `chart_interactions` - Daily interaction totals
  - `total_posts` - Total post count
  - `total_interactions` - Sum of all engagement
  - `total_views` - Sum of view counts
  - `average_interactions` - Mean interactions per post
  - `top_posts` - Top performing posts
  - `word_occurrences` - Word frequency hash
  - `bigram_occurrences` - Bigram frequency hash
  - `tag_counts` - Tag distribution
  - `tag_interactions` - Tag interaction breakdown
  - `positive_words` - Positive sentiment words
  - `negative_words` - Negative sentiment words

- `profiles_data` - Profile-level analytics
  - `profiles_count` - Posts by profile
  - `profiles_interactions` - Interactions by profile
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

- `viral_content` - Viral post analysis

# Data Sources

- `InstagramPost` model for post data
- `InstagramProfile` model for profile metadata
- `Topic` model for tag filtering
- Groupdate gem for temporal aggregation

# Key Differences from Facebook/Twitter

- Engagement metrics: likes, comments (simpler than Facebook's reaction breakdown)
- No view count estimation formula (uses actual API data when available)
- No sentiment analysis (unlike Facebook)

# Related

- [InstagramTopicController](controller.md) - Uses this service for data loading
- [Instagram Topic Views](views.md) - Consumes the aggregated data
- [InstagramPost Model](../models/instagram_post.md) - Primary data source
- [InstagramProfile Model](../models/instagram_profile.md) - Profile metadata source

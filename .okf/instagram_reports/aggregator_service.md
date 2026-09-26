---
type: Service
title: Instagram Aggregator Service
description: Main data aggregation service for Instagram topic analytics
resource: app/services/instagram_dashboard_services/aggregator_service.rb
tags: [instagram, reports, service, aggregation]
timestamp: 2026-09-26T00:00:00Z
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
  - `total_views` - `SUM(video_view_count)`, observed video views only; this is
    not unique reach and excludes content without provider video views. It is
    `nil` when no matched post has a provider-reported view value.
  - `views_source` - `:actual` for a non-null aggregate (including observed
    zero), otherwise `:unavailable`
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

## Cache Contract

The `instagram_dashboard:v7` snapshot is owned by the aggregator and expires in
30 minutes. It stores scalar KPIs and analytical values; `posts` and
`top_posts` are attached after the cache read so Active Record relations are not
serialized into the snapshot. Its key does not include `top_posts_limit`, so
requests with different limits share the same cached analytics payload. Service
specs verify that the shared snapshot is built once while each request attaches
its own limited `top_posts` relation.

`calculate_statistics` produces scalar KPIs only. `top_posts` is calculated once
by `attach_post_relations` after the cached snapshot is read.

The aggregator loads each temporal component once with its explicit
`start_time` and `end_time`, and derives `temporal_summary` from those values.
Topic temporal caches include the date range, preventing data calculated for a
different dashboard range from being reused.

## Recent Aggregation Changes

On 2026-09-26, KPI and temporal aggregation were simplified:

- KPI calculation no longer constructs `top_posts`; the relation is attached
  once after the cache read.
- Snapshot cache keys no longer include `top_posts_limit`; each request applies
  its own limit while attaching post relations after the cache read.
- Temporal components are loaded once, and the aggregator derives the summary
  from those values instead of calling the Topic summary method. Each component
  receives the dashboard date range and has a range-specific cache key.

Instagram has no sentiment-analysis payload. Its temporal intelligence still
receives the dashboard date range.

# Metric Contract

`calculate_statistics` returns `views_estimated: false`. Its `views_source` is
`:actual` only when the SQL aggregate is non-null, including a provider-reported
zero; it is `:unavailable` when no matched post has provider-reported views.
That provenance does not make it a reach metric: repeated views are possible and
non-video posts do not contribute a comparable view count. The service does not
use `InstagramPost#estimated_reach` as a fallback.

# Key Differences from Facebook/Twitter

- Engagement metrics: likes, comments (simpler than Facebook's reaction breakdown)
- Observed video views are available only for applicable video content; no
  approved fallback formula exists for unavailable values
- No sentiment analysis (unlike Facebook)

# Performance

- The service passes its already-loaded topic tag names to `InstagramPost.for_topic`, avoiding a second tag lookup for the primary dashboard scope.
- Word and bigram frequencies are produced together from one traversal of the filtered posts.

# Related

- [InstagramTopicController](controller.md) - Uses this service for data loading
- [Instagram Topic Views](views.md) - Consumes the aggregated data
- [InstagramPost Model](../models/instagram_post.md) - Primary data source
- [InstagramProfile Model](../models/instagram_profile.md) - Profile metadata source
- [Views Estimation](../business_rules/views_estimation.md) - Video-view semantics and fallback decision

# Citations

- Production read-only Instagram analysis, 2026-09-26.

---
type: Architecture
title: Aggregator Services
description: Dashboard data aggregation services for all platform analytics
tags: [services, aggregation, dashboards, performance]
timestamp: 2026-09-26T00:00:00Z
---

# Overview

Morfeo uses a family of aggregator services to load, cache, and calculate dashboard data for all analytics views. Each service follows the ApplicationService pattern with `.call()` class method and handles data loading, caching, and complex calculations for its respective dashboard.

# Service Architecture

All aggregator services inherit from `ApplicationService` and follow a consistent pattern:

```ruby
class AggregatorService < ApplicationService
  CACHE_EXPIRATION = 30.minutes

  def initialize(topic:, days_range: DAYS_RANGE)
    # Initialize parameters and cache tag names
  end

  def call
    Rails.cache.fetch(cache_key, expires_in: CACHE_EXPIRATION) do
      # Load and aggregate data
    end
  end
end
```

# Aggregator Services

## Digital Dashboard Aggregator

**Location**: `app/services/digital_dashboard_services/aggregator_service.rb`

**Purpose**: Aggregates digital media (web article) dashboard data

**Key Features**:

- Loads entries for topic with date range filtering
- Calculates entry aggregations (counts, totals, polarity breakdowns)
- Computes site data (entries per site, interactions per site)
- Generates chart data (posts/day, interactions/day)
- Performs text analysis (word/bigram occurrences)
- Detects viral content

**Cache Keys**: `digital_dashboard:v4:topic:{topic_id}:{resource}:{start_date}:{end_date}`

`resource` identifies the payload (`payload`, `site_data`, or `text_analysis`).
The global Share of Voice aggregate uses
`digital_dashboard:v4:global_stats:{start_date}:{end_date}`. These aggregator-
owned caches are 30-minute snapshots and do not include entry count or update
state in their keys. The manual `cache:clear` task clears both the old `v3` and
current `v4` namespaces during the transition.

## Facebook Dashboard Aggregator

**Location**: `app/services/facebook_dashboard_services/aggregator_service.rb`

**Purpose**: Aggregates Facebook topic dashboard data

**Key Features**:

- Loads Facebook entries for topic with date range
- Calculates chart data (posts/day, interactions/day)
- Computes statistics (total posts, interactions, views, averages)
- Performs text analysis (word/bigram occurrences)
- Calculates tag data (tag distribution, interactions by tag)
- Loads pages data (posts per page, interactions per page)
- Performs sentiment analysis (reaction breakdown, sentiment labels)
- Detects viral content

**Cache Key**: `facebook_dashboard:v4:topic:{topic_id}:limit:{top_posts_limit}:payload:{start_date}:{end_date}`

## Twitter Dashboard Aggregator

**Location**: `app/services/twitter_dashboard_services/aggregator_service.rb`

**Purpose**: Aggregates Twitter topic dashboard data

**Key Features**:

- Loads Twitter posts for topic with date range
- Calculates chart data (posts/day, interactions/day)
- Computes statistics (total posts, interactions, views, averages)
- Performs text analysis (word/bigram occurrences)
- Calculates tag data (tag distribution, interactions by tag)
- Loads profiles data (posts per profile, interactions per profile)
- Detects viral content

**Cache Key**: `twitter_dashboard:v4:topic:{topic_id}:limit:{top_posts_limit}:payload:{start_date}:{end_date}`

## Instagram Dashboard Aggregator

**Location**: `app/services/instagram_dashboard_services/aggregator_service.rb`

**Purpose**: Aggregates Instagram topic dashboard data

**Key Features**:

- Loads Instagram posts for topic with date range
- Calculates chart data (posts/day, interactions/day)
- Computes statistics (total posts, interactions, video views, averages)
- Performs text analysis (word/bigram occurrences)
- Calculates tag data (tag distribution, interactions by tag)
- Loads profiles data (posts per profile, interactions per profile)
- Detects viral content

**Cache Key**: `instagram_dashboard:v4:topic:{topic_id}:limit:{top_posts_limit}:payload:{start_date}:{end_date}`

## General Dashboard Aggregator

**Location**: `app/services/general_dashboard_services/aggregator_service.rb`

**Purpose**: Professional aggregation service for CEO-level reporting combining all sources

**Key Features**:

- Combines data from Digital Media, Facebook, Twitter, and Instagram
- Builds executive summary (total mentions, interactions, reach, sentiment)
- Calculates channel performance (per-platform metrics) and cross-channel totals
- Performs temporal intelligence (trend analysis)
- Analyzes sentiment across all channels
- Computes reach analysis with provenance: `reach_estimated` is true for multiplier-derived values (digital always; Twitter only when observed views are unavailable). These values must be presented as `Estimated Reach`, not observed reach.
- Builds competitive analysis
- Identifies top content and viral content across all platforms
- Generates publishing-time recommendations only from available temporal engagement data; it does not supply a default day or time.

**Cache Key**: `general_dashboard:v5:topic:{topic_id}:payload:{start_date}:{end_date}`

All dashboard `show` actions delegate KPI and analytical-value freshness to
their aggregator snapshots. Digital and social aggregators attach their primary
entry/post relations after a snapshot is read; General caches only stable
top-content metadata and attaches digital entries, Facebook posts, tweets,
Instagram posts, and viral-content relations after a snapshot is read. This
prevents the cache-miss path from building those relations twice.

### General Dashboard Instagram Contract

Instagram is a fourth General Dashboard channel. Its topic-scoped metrics use
the selected date range and topic tags: mentions are post counts, interactions
are likes plus comments, and reach is observed `video_view_count` without a
fallback multiplier. Instagram therefore participates in total mentions, total
interactions, total reach, channel performance, Share of Voice, growth rate,
combined temporal recommendations, top content, and viral-content analysis.

Instagram temporal calls receive the General Dashboard `start_date` and
`end_date`, matching Facebook and Twitter range semantics. Instagram has no
sentiment source equivalent to digital or Facebook analysis, so it is displayed
as neutral at channel level and is deliberately excluded from the weighted global
sentiment and distribution calculations.

## Home Dashboard Aggregator

**Location**: `app/services/home_services/dashboard_aggregator_service.rb`

**Purpose**: Aggregates cross-topic home dashboard metrics.

**Cache Key**: `home_dashboard:v4:topics:{sorted_unique_topic_ids}:payload:{start_date}:{end_date}`

The key includes the complete sorted topic set, so a topic update invalidates the
Home namespace as well as the affected topic-specific dashboard caches. The
payload includes `word_occurrences` for the Tags Cloud, so a cache hit performs
no text-corpus analysis.

## Site Dashboard Aggregator

**Location**: `app/services/site_dashboard_services/aggregator_service.rb`

**Purpose**: Aggregates site-specific dashboard data

**Key Features**:

- Loads entries stats (grouped by day)
- Loads entries with associations for display
- Calculates word occurrences (cached, limited to 500 entries)
- Calculates bigram occurrences (cached, limited to 500 entries)
- Loads tag data (tag distribution, interactions by tag)

**Cache Key**: `site_dashboard_{site_id}_{date}`

# Performance Optimizations

## Caching Strategy

All aggregator services use Redis caching with 30-minute expiration:

```ruby
Rails.cache.fetch(cache_key, expires_in: CACHE_EXPIRATION) do
  # Expensive data loading and calculations
end
```

## Memoization

Services use instance variable memoization to avoid repeated calculations:

```ruby
def topic_data
  @topic_data_cache ||= load_topic_data
end
```

## Query Optimization

- **Single base queries**: Load all necessary data in one query with includes
- **Database-level aggregation**: Use SQL GROUP BY and SUM instead of Ruby loops
- **Digital temporal intelligence**: Cache a day/hour aggregate and one conditional velocity aggregate per topic. On a cold cache this derives heatmap, hour/day peaks, optimal time, and both velocity metrics in two SQL queries; content half-life remains a separate bounded 100-row `published_at`/`total_count` query.
- **Limited text analysis**: Cap entries for word/bigram analysis (500 max)
- **Efficient sorting**: Use database ORDER BY for top posts
- **General dashboard digital metrics**: Fetch current mention count and interactions in one aggregate query; derive reach from the returned interaction total.
- **Shared text analysis**: `Entry`, `FacebookEntry`, `TwitterPost`, and `InstagramPost` expose `text_occurrences`, allowing word and bigram results to share one source traversal. General reuses the combined result for its recommendation paths and passes its cached tag names to social scopes. `combined_text_occurrences` must return a hash with `word_occurrences` and `bigram_occurrences`; content relations belong to their own methods and must not become its final expression.
- **Digital tag metrics**: Home dashboard digital metrics resolve topic tag IDs once and filter `Entry` with `with_any_tag_ids(..., context: :tags)`. This preserves immediate tagging freshness and avoids counting title-tag matches as content mentions.
- **Tagged social counts**: On `tagged_with(..., any: true)` relations, pass an explicit primary key to `count`, such as `count(:id)`. A bare `count` can generate `COUNT(table.*)`, which MariaDB/MySQL rejects. The tag filter remains an `EXISTS` subquery, so matching multiple tags does not duplicate a social post.

## Batch Processing

Aggregations are batched to minimize database queries:

```ruby
def calculate_entry_aggregations(entries)
  # Precompute aggregates in single pass
  entries_count = entries.distinct.count
  entries_total_sum = entries.distinct.sum(:total_count)
  # ... combined queries
end
```

# Usage Pattern

Controllers use aggregator services to load dashboard data:

```ruby
def show
  @data = DigitalDashboardServices::AggregatorService.call(topic: @topic)
  # @data contains all pre-calculated dashboard data
end
```

# Related

- [Caching Strategy](caching_strategy.md) - Overall caching architecture
- [Digital Reports](digital_reports/) - Digital media analytics
- [Facebook Reports](facebook_reports/) - Facebook analytics
- [Twitter Reports](twitter_reports/) - Twitter analytics
- [Instagram Reports](instagram_reports/) - Instagram analytics
- [Instagram Aggregator Service](instagram_reports/aggregator_service.md) - Source Instagram dashboard contract

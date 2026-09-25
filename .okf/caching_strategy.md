---
type: Architecture
title: Caching Strategy
description: Multi-layer caching architecture for fast report generation and dashboard performance
tags: [caching, performance, redis, optimization]
timestamp: 2026-09-25T00:00:00Z
---

# Overview

Morfeo uses a multi-layer caching strategy to deliver fast report generation and dashboard performance. The architecture combines Redis-backed caching, action caching, service-level memoization, and proactive cache warming.

# Cache Infrastructure

## Cache Store

- **Production**: Redis cache store (`redis://localhost:6379/0`)
- **Development**: Memory store (or null store when caching disabled)
- **Namespace**: Application root path for cache key isolation

## Cache Duration

- **Standard**: 30 minutes for all dashboard and report data
- **PDF Generation**: 30 minutes per topic/type/days_range combination
- **Cache Warming**: Every 5 minutes to maintain fresh data

# Caching Layers

## 1. Action Caching (Controller Level)

Controllers use `caches_action` to cache rendered views:

```ruby
caches_action :show, :pdf, expires_in: 30.minutes,
              cache_path: proc { |c| { topic_id: c.params[:id], user_id: c.current_user.id, days_range: c.params[:days_range] } }
```

**Applied to:**

- All topic dashboard controllers (digital, Facebook, Twitter, Instagram)
- Entry controller (popular, commented, week views)
- Tag controller (show, report, pdf)
- Home controller (index)

## 2. Service-Level Caching

Dashboard aggregator services cache expensive data loading operations:

```ruby
Rails.cache.fetch(cache_key, expires_in: CACHE_EXPIRATION) do
  # Expensive data loading and calculations
end
```

### Stampede Protection

Dashboard aggregators use `ApplicationService#fetch_cached_with_race_protection`,
which adds `race_condition_ttl: 2.minutes` to every dashboard cache fetch. When
a Redis entry has just expired, the first request refreshes it while concurrent
requests receive the prior value for up to two minutes instead of repeating the
same expensive aggregation. If refresh fails, Rails permits another request to
try again after that window.

This protection applies to the payload caches for Digital, Facebook, Twitter,
Instagram, General, and Home dashboards, plus Digital's costly site-data,
text-analysis, and global-statistics subcaches. It deliberately does not add a
custom Redis lock: stale-while-revalidate avoids request blocking while retaining
the existing 30-minute freshness contract.

**Cache Keys Include:**

- Topic ID
- Effective date range (including the normalized `days_range` for dashboard subcaches)
- Current date (for daily freshness)
- User ID (for personalized data)

**Services Using Caching:**

- `DigitalDashboardServices::AggregatorService`
- `FacebookDashboardServices::AggregatorService`
- `TwitterDashboardServices::AggregatorService`
- `InstagramDashboardServices::AggregatorService`
- `GeneralDashboardServices::AggregatorService`
- `HomeServices::DashboardAggregatorService`
- `SiteDashboardServices::AggregatorService`

### Versioned Dashboard Keys

Dashboard caches use versioned namespaces with ISO date boundaries:

```
digital_dashboard:v3:topic:{topic_id}:{resource}:{start_date}:{end_date}
digital_dashboard:v3:global_stats:{start_date}:{end_date}
facebook_dashboard:v3:topic:{topic_id}:limit:{limit}:payload:{start_date}:{end_date}
twitter_dashboard:v3:topic:{topic_id}:limit:{limit}:payload:{start_date}:{end_date}
instagram_dashboard:v3:topic:{topic_id}:limit:{limit}:payload:{start_date}:{end_date}
general_dashboard:v3:topic:{topic_id}:payload:{start_date}:{end_date}
home_dashboard:v3:topics:{sorted_unique_topic_ids}:payload:{start_date}:{end_date}
```

The digital topic resources are `payload`, `site_data`, and `text_analysis`.
Cache maintenance tasks invalidate each namespace with its `:v3:*` pattern or a
topic-specific prefix. Updating a topic also invalidates `home_dashboard:v3:*`
because its payload depends on the active topic set. The Home key normalizes its
topic IDs as a sorted unique set, preventing duplicate or order-only cache
variants.

### Digital Share of Voice

When `USE_DIRECT_ENTRY_TOPICS=true`, the cached global digital aggregate used for
Share of Voice has the same universe as `Topic#all_list_entries`: enabled entries
within the topic default date range that have a site. The legacy Elasticsearch
path continues to use `all_list_entries` directly.

## 3. PDF Caching

The `PdfCacheable` concern provides intelligent PDF caching:

```ruby
def fetch_cached_pdf(type:, topic_id:, days_range:, **options, &block)
  cache_key = self.class.pdf_cache_key(type: type, topic_id: topic_id, days_range: days_range, **options)
  Rails.cache.fetch(cache_key, expires_in: cache_duration, &block)
end
```

**Cache Key Structure:**

```
pdf/{type}/{topic_id}/{days_range}/{date}
```

**Cache Duration by Type:**

- Digital: 30 minutes
- Facebook: 30 minutes
- Twitter: 30 minutes
- Instagram: 30 minutes
- General: 30 minutes

## 4. Cache Warming

Proactive cache population via scheduled rake task:

```ruby
# config/schedule.rb
every 5.minutes do
  rake 'cache:warm_dashboards'
end
```

**Purpose:**

- Pre-load dashboard data into Redis cache
- Ensure fast first-time access
- Maintain fresh data (30-minute expiration)
- `cache:warm_dashboards` measures each dashboard invocation with a monotonic clock and reports per-topic totals, slowest calls, and aggregate timings.
- Cache status is inferred from ActiveSupport cache read and generation notifications during each service invocation. `HIT` means the invocation observed a cache read hit; `MISS` means cache generation occurred; `UNKNOWN` is reported if neither notification is available.

# Memoization Patterns

Services use instance variable memoization for repeated calculations:

```ruby
def topic_data
  @topic_data_cache ||= load_topic_data
end

def tag_names
  @tag_names ||= @topic.tags.pluck(:name)
end
```

# Cache Invalidation

## Automatic Expiration

All caches expire after 30 minutes, ensuring data freshness without manual invalidation.

## Manual Invalidation

```ruby
# Expire specific PDF cache
expire_pdf_cache(type: :digital, topic_id: 1, days_range: 7)

# Expire all caches for a topic
Rails.cache.delete_matched("pdf/*/#{topic_id}/*")
```

# Performance Benefits

1. **Reduced Database Load**: Cached queries avoid repeated expensive database operations
2. **Faster PDF Generation**: Pre-cached PDFs serve instantly instead of regenerating
3. **Improved Dashboard Response**: Aggregated data loads from cache in milliseconds
4. **Scalable Architecture**: Redis caching supports multiple application instances

# Configuration

## Production (`config/environments/production.rb`)

```ruby
config.cache_classes = true
config.action_controller.perform_caching = true
config.cache_store = :redis_cache_store, { url: 'redis://localhost:6379/0', namespace: Rails.root.to_s }
```

## Development (`config/environments/development.rb`)

```ruby
config.cache_classes = false
config.action_controller.perform_caching = false
config.cache_store = :null_store
```

Toggle development caching with `rails dev:cache`.

# Related

- [Digital Reports](digital_reports/) - Digital media analytics
- [Facebook Reports](facebook_reports/) - Facebook analytics
- [Twitter Reports](twitter_reports/) - Twitter analytics
- [Instagram Reports](instagram_reports/) - Instagram analytics
- [Reporting](business_rules/reporting.md) - Report generation rules

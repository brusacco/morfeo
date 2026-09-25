---
type: Architecture
title: Scheduled Tasks
description: Complete documentation of all cron-scheduled rake tasks and their purposes
tags: [scheduling, cron, rake, automation, tasks]
timestamp: 2026-09-25T00:00:00Z
---

# Overview

Morfeo uses the `whenever` gem to manage cron jobs defined in `config/schedule.rb`. The schedule is organized into frequency tiers: cache warming (10 min), hourly data collection, 3-hour social media crawling, 4-hour tagging, 6-hour deep processing, daily deep operations, and weekly maintenance.

# Schedule Configuration

**File**: `config/schedule.rb`
**Environment**: `production`
**Gem**: `whenever` (generates crontab entries)

# Task Schedule

## Cache Warming - Every 10 Minutes

### `cache:warm_dashboards`

- **Purpose**: Pre-loads dashboard data into Redis cache to keep dashboards fast
- **Frequency**: Every 10 minutes
- **Cache Expiration**: All caches expire after 30 minutes, ensuring fresh data
- **Home Dashboard**: Warms each distinct active-topic set assigned to users,
  deduplicating equivalent sets and including the empty set when applicable.
- **Diagnostics**: When one dashboard fails for a topic, the topic summary keeps
    that dashboard's error class, message, and optional debug backtrace; the
    detailed performance report continues to identify the failing dashboard.
- **Related**: [Caching Strategy](caching_strategy.md)

## Hourly Tasks - Core Data Collection

### `crawler`

- **Purpose**: Crawl websites for new articles (depth: 2)
- **Frequency**: Every hour
- **Related**: [Content Crawling](business_rules/content_crawling.md)

### `proxy_crawler`

- **Purpose**: Crawl JavaScript-rendered sites via proxy service
- **Frequency**: Every hour
- **Related**: [Content Crawling](business_rules/content_crawling.md)

### `facebook:update_linked_stats`

- **Purpose**: Update Facebook engagement stats for entries linked to Facebook posts
- **Frequency**: Every hour

### `update_dates`

- **Purpose**: Fix and standardize publication dates across entries
- **Frequency**: Every hour

### `clean_site_content`

- **Purpose**: Remove unwanted content and formatting from scraped articles
- **Frequency**: Every hour

### `category`

- **Purpose**: Categorize entries based on content analysis
- **Frequency**: Every hour

### `topic_stat_daily`

- **Purpose**: Generate daily statistics per topic (entry counts, interactions, sentiment)
- **Frequency**: Every hour
- **Related**: [Topic Model](models/topic.md)

### `title_topic_stat_daily`

- **Purpose**: Generate title-based daily statistics per topic
- **Frequency**: Every hour

## Every 3 Hours - Social Media Crawling

### `facebook:fanpage_crawler[1]`

- **Purpose**: Crawl Facebook pages for new posts (3 pages = ~300 posts per page)
- **Frequency**: Every 3 hours
- **Related**: [Facebook Services](facebook_reports/facebook_services.md)

### `twitter:profile_crawler_full`

- **Purpose**: Full crawl of Twitter profiles for new tweets (updates existing engagement metrics)
- **Frequency**: Every 3 hours
- **Related**: [Twitter Services](twitter_reports/twitter_services.md)

### `social_crawler`

- **Purpose**: General social media crawler for additional platforms
- **Frequency**: Every 3 hours

### `update_site_stats`

- **Purpose**: Aggregate site-level statistics
- **Frequency**: Every 3 hours

## Every 4 Hours - Content Tagging

### `repeated_notes`

- **Purpose**: Detect and mark duplicate articles
- **Frequency**: Every 4 hours

### `instagram:posts_crawler`

- **Purpose**: Crawl Instagram posts from tracked profiles
- **Frequency**: Every 4 hours
- **Related**: [Instagram Services](instagram_reports/instagram_services.md)

## Every 6 Hours - Deep Processing and AI

### `ai:generate_ai_reports`

- **Purpose**: Generate AI-powered topic reports using OpenAI
- **Frequency**: Every 6 hours
- **Related**: [Sentiment Analysis](business_rules/sentiment_analysis.md)

### `ai:set_topic_polarity`

- **Purpose**: Set sentiment/polarity for topics based on AI analysis
- **Frequency**: Every 6 hours

### `facebook:update_fanpages`

- **Purpose**: Update Facebook page metadata (followers, descriptions, etc.)
- **Frequency**: Every 6 hours

### `tagger`

- **Purpose**: Re-tag entries from last 7 days (default)
- **Frequency**: Every 6 hours
- **Related**: [Topic Organization](business_rules/topic_organization.md)

### `instagram:posts_crawler`

- **Purpose**: Crawl Instagram posts (second run)
- **Frequency**: Every 6 hours

## Daily at 3:00 AM - Deep Re-tagging

### `crawler[3]`

- **Purpose**: Deep crawl for missed content (depth: 3)
- **Frequency**: Daily at 3:00 AM
- **Note**: Runs when server load is lowest

### `tagger[60]`

- **Purpose**: Deep re-tag last 60 days (includes automatic sync)
- **Frequency**: Daily at 3:00 AM
- **Note**: Comprehensive re-tagging for accuracy

## Weekly on Sundays at 4:00 AM - Full Sync Safety Check

### `topic:sync_all[60]`

- **Purpose**: Weekly safety sync for all topics (60-day range)
- **Frequency**: Sundays at 4:00 AM
- **Note**: Temporary safety net while verifying daily tagger[60] is sufficient
- **Related**: [Topic Organization](business_rules/topic_organization.md)

## Weekly on Sundays at 5:00 AM - 60-Day Statistics Update

### `topic_stat_daily[60]`

- **Purpose**: Update 60-day daily statistics for all topics
- **Frequency**: Sundays at 5:00 AM
- **Note**: Supports all PDF report ranges

### `title_topic_stat_daily[60]`

- **Purpose**: Update 60-day title-based statistics for all topics
- **Frequency**: Sundays at 5:00 AM

## Daily at 6:00 AM - Health Check

### `audit:sync_health`

- **Purpose**: Audit sync health and alert if issues are detected
- **Frequency**: Daily at 6:00 AM
- **Note**: Runs after sync completes, before business hours start

# Commented Out Tasks (Available but Not Scheduled)

### `twitter:link_to_entries`

- **Purpose**: Link tweets to news articles by URL matching
- **Status**: Commented out (available for manual or 12-hour scheduling)

### `facebook:link_to_entries`

- **Purpose**: Link Facebook posts to news articles by URL matching
- **Status**: Commented out (available for manual or 12-hour scheduling)

### `twitter:post_tagger`

- **Purpose**: Tag Twitter posts using Tag vocabulary
- **Status**: Commented out (available for manual or 12-hour scheduling)

### `facebook:entry_tagger`

- **Purpose**: Tag Facebook entries using Tag vocabulary
- **Status**: Commented out (available for manual or 12-hour scheduling)

# Task Dependencies and Ordering

The schedule is designed with dependencies in mind:

1. **Data Collection First**: Crawlers run before processing tasks
2. **Processing Before Reporting**: Tagging and categorization run before statistics generation
3. **Deep Operations at Low Traffic**: Heavy tasks (deep crawl, 60-day re-tag) run at 3 AM
4. **Safety Checks After Processing**: Health checks run after sync operations complete
5. **Statistics Before Business Hours**: 60-day stats update before daily operations begin

# Related

- [Content Crawling](business_rules/content_crawling.md) - Crawling business rules
- [Topic Organization](business_rules/topic_organization.md) - Topic organization rules
- [Social Media Integration](business_rules/social_media_integration.md) - Social media integration rules
- [Caching Strategy](caching_strategy.md) - Cache warming strategy

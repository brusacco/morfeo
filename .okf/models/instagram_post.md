---
type: Model
title: InstagramPost
description: Instagram posts from tracked profiles with engagement metrics
resource: app/models/instagram_post.rb
tags: [social, instagram, analytics]
timestamp: 2026-09-26T00:00:00Z
---

# Overview

The InstagramPost model stores posts from tracked Instagram profiles with engagement metrics.

# Schema

| Field                | Type     | Description                                                                        |
| -------------------- | -------- | ---------------------------------------------------------------------------------- |
| shortcode            | string   | Unique Instagram shortcode                                                         |
| posted_at            | datetime | Post publication date                                                              |
| caption              | text     | Post caption                                                                       |
| media_type           | string   | GraphImage, GraphVideo, GraphSidecar                                               |
| product_type         | string   | feed, clips (reels)                                                                |
| likes_count          | integer  | Like count                                                                         |
| comments_count       | integer  | Comment count                                                                      |
| video_view_count     | bigint   | Observed provider video views; nullable and applicable only to video posts         |
| total_count          | integer  | Provider total stored at ingestion; dashboard interactions use likes plus comments |
| instagram_profile_id | integer  | Foreign key to InstagramProfile                                                    |
| entry_id             | integer  | Optional foreign key to Entry                                                      |

# Associations

- `belongs_to :instagram_profile` - The profile that posted ([InstagramProfile](instagram_profile.md))
- `belongs_to :entry, optional: true` - Linked news article ([Entry](entry.md))
- `acts_as_taggable_on :tags` - Topic tags ([Tag](tag.md))

# Key Methods

- `self.for_topic(topic, start_time:, end_time:)` - Filter by topic and date range
- `self.grouped_counts(scope, format)` - Daily post counts
- `self.grouped_interactions(scope, format)` - Daily interaction totals
- `self.total_views(scope)` - Sum of observed `video_view_count`; not unique reach
- `estimated_reach` - Legacy model estimate: `total_interactions * 10`, with a
  $1.5$ video/reel multiplier. It is not used as observed video views and is not
  approved as a fallback calibration.

# Metric Semantics

`total_interactions` is exactly `likes_count + comments_count`. It does not
include shares or saves because Morfeo does not ingest those fields. The
ingestion service saves `video_view_count` directly from the provider without a
zero default, so `NULL` means the provider did not supply a usable video-view
value in the captured payload; zero remains distinguishable.

Observed video views must be labeled as views, never as unique reach. Production
analysis found observed views with zero interactions, so an interactions-only
fallback cannot safely replace unavailable video views.

# Related

- [Instagram Reports Infrastructure](../instagram_reports/) - Analytics dashboard for Instagram posts
- [Instagram Services](../instagram_reports/instagram_services.md) - API integration services
- [Social Media Integration](../business_rules/social_media_integration.md) - Instagram integration rules
- [Engagement Metrics](../business_rules/engagement_metrics.md) - Instagram engagement calculations
- [Views Estimation](../business_rules/views_estimation.md) - Observed-video and fallback limits

# Citations

- Production read-only Instagram analysis, 2026-09-26.

---
type: Model
title: InstagramPost
description: Instagram posts from tracked profiles with engagement metrics
resource: app/models/instagram_post.rb
tags: [social, instagram, analytics]
timestamp: 2026-09-22T00:00:00Z
---

# Overview

The InstagramPost model stores posts from tracked Instagram profiles with engagement metrics.

# Schema

| Field                | Type     | Description                          |
| -------------------- | -------- | ------------------------------------ |
| shortcode            | string   | Unique Instagram shortcode           |
| posted_at            | datetime | Post publication date                |
| caption              | text     | Post caption                         |
| media_type           | string   | GraphImage, GraphVideo, GraphSidecar |
| product_type         | string   | feed, clips (reels)                  |
| likes_count          | integer  | Like count                           |
| comments_count       | integer  | Comment count                        |
| instagram_profile_id | integer  | Foreign key to InstagramProfile      |
| entry_id             | integer  | Optional foreign key to Entry        |

# Associations

- `belongs_to :instagram_profile` - The profile that posted ([InstagramProfile](instagram_profile.md))
- `belongs_to :entry, optional: true` - Linked news article ([Entry](entry.md))
- `acts_as_taggable_on :tags` - Topic tags ([Tag](tag.md))

# Key Methods

- `self.for_topic(topic, start_time:, end_time:)` - Filter by topic and date range
- `self.grouped_counts(scope, format)` - Daily post counts
- `self.grouped_interactions(scope, format)` - Daily interaction totals

# Related

- [Instagram Reports Infrastructure](../instagram_reports/) - Analytics dashboard for Instagram posts
- [Instagram Services](../instagram_reports/instagram_services.md) - API integration services
- [Social Media Integration](../business_rules/social_media_integration.md) - Instagram integration rules
- [Engagement Metrics](../business_rules/engagement_metrics.md) - Instagram engagement calculations

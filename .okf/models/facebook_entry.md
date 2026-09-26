---
type: Model
title: FacebookEntry
description: Facebook posts from tracked Pages with comprehensive engagement metrics
resource: app/models/facebook_entry.rb
tags: [social, facebook, analytics]
timestamp: 2026-09-22T00:00:00Z
---

# Overview

The FacebookEntry model stores posts from tracked Facebook Pages with full engagement metrics including reaction breakdowns, comments, shares, and estimated views.

# Schema

| Field                    | Type     | Description                          |
| ------------------------ | -------- | ------------------------------------ |
| facebook_post_id         | string   | Unique Facebook post ID              |
| posted_at                | datetime | Post publication date                |
| message                  | text     | Post text content                    |
| permalink_url            | string   | URL to the post                      |
| attachment_type          | string   | Type of attachment                   |
| attachment_title         | string   | Attachment title                     |
| attachment_description   | text     | Attachment description               |
| attachment_url           | string   | Attachment URL                       |
| attachment_target_url    | string   | Target URL (expanded)                |
| attachment_media_src     | string   | Media source URL                     |
| reactions_like_count     | integer  | Like reactions                       |
| reactions_love_count     | integer  | Love reactions                       |
| reactions_wow_count      | integer  | Wow reactions                        |
| reactions_haha_count     | integer  | Haha reactions                       |
| reactions_sad_count      | integer  | Sad reactions                        |
| reactions_angry_count    | integer  | Angry reactions                      |
| reactions_thankful_count | integer  | Thankful reactions                   |
| reactions_total_count    | integer  | Total reactions                      |
| comments_count           | integer  | Comment count                        |
| share_count              | integer  | Share count                          |
| views_count              | integer  | Estimated views                      |
| sentiment_label          | enum     | very_negative(0) to very_positive(4) |
| controversy_index        | float    | Controversy score                    |
| emotional_intensity      | float    | Emotional intensity score            |
| page_id                  | integer  | Foreign key to Page                  |
| entry_id                 | integer  | Optional foreign key to Entry        |

# Views Estimation Formula

Facebook reach is a Morfeo estimate, not a Meta-provided reach metric. It uses a
bounded follower-based model:

`followers * 0.01 * (1 + 10 * min(total_interactions / followers, 0.03))`

Estimated views apply Morfeo's $1.2$ repeated-exposure assumption to estimated
reach. The `before_save :calculate_views_count` callback persists the resulting
estimated views in `views_count` for new or updated records.

# Key Methods

- `self.for_topic(topic, start_time:, end_time:)` - Filter by topic and date range
- `self.grouped_counts(scope, format)` - Daily post counts
- `self.grouped_interactions(scope, format)` - Daily interaction totals
- `self.total_interactions(scope)` - Sum of all engagement
- `self.total_views(scope)` - Sum of estimated views
- `self.word_occurrences(scope, limit)` - Word frequency analysis
- `self.bigram_occurrences(scope, limit)` - Bigram frequency analysis
- `find_matching_entry` - Find Entry with matching URL
- `link_to_entry!` - Create association with Entry
- `external_urls` - Extract URLs from post
- `normalize_url` - Generate URL variations for matching

# Associations

- `belongs_to :page` - The Facebook page that posted this ([Page](page.md))
- `belongs_to :entry, optional: true` - Linked news article (if URL matches) ([Entry](entry.md))
- `acts_as_taggable_on :tags` - Topic tags ([Tag](tag.md))

# URL Matching

The system can automatically link Facebook posts to news articles they reference by matching URLs from `attachment_target_url` and `attachment_url` against Entry URLs, handling variations (www, query params, trailing slashes).

# Related

- [Facebook Reports Infrastructure](../facebook_reports/) - Analytics dashboard for Facebook posts
- [Facebook Services](../facebook_reports/facebook_services.md) - API integration services
- [Social Media Integration](../business_rules/social_media_integration.md) - Facebook integration rules
- [URL Matching](../business_rules/url_matching.md) - Linking Facebook posts to entries
- [Engagement Metrics](../business_rules/engagement_metrics.md) - Facebook engagement calculations
- [Sentiment Analysis](../business_rules/sentiment_analysis.md) - Facebook sentiment rules
- [Views Estimation](../business_rules/views_estimation.md) - Facebook views formula

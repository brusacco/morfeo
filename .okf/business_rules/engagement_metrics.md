---
type: Business Rule
title: Engagement Metrics
description: Platform-specific engagement metric calculations
tags: [engagement, metrics, analytics, calculations]
timestamp: 2026-09-26T00:00:00Z
---

# Overview

Each platform has different engagement metrics. Morfeo calculates total interactions differently for each platform based on available data.

# Rules

## Digital Media (Entries)

- Metrics: `reaction_count`, `comment_count`, `share_count`, `total_count`
- Total interactions: Sum of all social metrics
- Data source: Facebook Graph API for URL engagement

## Facebook

- Metrics: Individual reaction counts (like, love, wow, haha, sad, angry, thankful), `reactions_total_count`, `comments_count`, `share_count`, `views_count`
- Total interactions: `reactions_total_count + comments_count + share_count`
- Views: Estimated using formula (see [Views Estimation](views_estimation.md))

## Twitter

- Metrics: `favorite_count`, `retweet_count`, `reply_count`, `quote_count`, `views_count`, `bookmark_count`
- Total interactions: `favorite_count + retweet_count + reply_count + quote_count`
- Views: Real API data (not estimated)

## Instagram

- Metrics: `likes_count`, `comments_count`, and provider-supplied
  `video_view_count` for video posts
- Total interactions: `likes_count + comments_count`
- Video views: observed where `video_view_count` is present; they are not unique
  reach. The current ingest path preserves `NULL` for a missing video-view field
  but maps missing likes/comments to zero, so only the former distinguishes
  absence from an observed zero.
- Shares and saves: unavailable in the current post schema and ingestion flow.

# Analytics Calculations

All platforms support:

- Daily post counts (`grouped_counts`)
- Daily interaction totals (`grouped_interactions`)
- Total interactions across scope (`total_interactions`)
- Total views across scope (`total_views`)
- Word frequency analysis (`word_occurrences`)
- Bigram frequency analysis (`bigram_occurrences`)

# Related

- [Views Estimation](views_estimation.md) - Facebook views calculation
- [Entry Model](../models/entry.md) - Digital media metrics
- [FacebookEntry Model](../models/facebook_entry.md) - Facebook metrics
- [TwitterPost Model](../models/twitter_post.md) - Twitter metrics
- [InstagramPost Model](../models/instagram_post.md) - Instagram metrics
- [Views Estimation](views_estimation.md) - Observed-video and fallback rules

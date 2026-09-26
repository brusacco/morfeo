---
type: Business Rule
title: Views Estimation
description: Views calculation rules by platform
tags: [views, estimation, calculations, facebook]
timestamp: 2026-09-22T00:00:00Z
---

# Overview

Different platforms provide view data differently. Morfeo estimates Facebook visualizations, while Twitter/X provides observed view counts when available and Instagram provides observed video views.

# Rules

## Facebook (Estimated)

Facebook doesn't provide direct view counts, so Morfeo estimates reach with a bounded follower-based formula:

```
engagement_rate = total_interactions / followers
estimated_reach = followers * 0.01 * (1 + 10 * min(engagement_rate, 0.03))
estimated_views = estimated_reach * 1.2
```

- Engagement changes reach only from 1.00% to 1.30% of followers.
- The engagement-rate adjustment is capped at 3%.
- Shares, comments, and reactions contribute through `total_interactions`; they
  are not converted directly into additional people reached.
- Content type does not alter the Facebook reach estimate.
- The $1.2$ views factor is a Morfeo assumption for approximately 20% repeated
  exposure over estimated reach, not observed Meta data.

## Twitter/X (Observed When Available)

- X API provides observed view counts when `views_count` is present
- Stored directly in `views_count` field
- The General and Home dashboards use an `interactions * 10` fallback when views are unavailable. That fallback must be classified as `fallback_estimate`.

## Instagram (Observed Video Views)

- Provider-supplied `video_view_count` is stored for video posts and presented as video views, not reach.
- `InstagramPost#estimated_reach` is a separate model-derived value and must not be presented as an observed provider metric.

## Cross-Channel Reporting

- Digital reach (`interactions * 3`) is `estimated`.
- Facebook `views_count` is `estimated`; it is derived by `FacebookEntry#calculate_views_count` and is not a Meta-provided reach metric.
- Cross-channel totals mix observed views with modeled values. They must be flagged as estimated and must not be described as unique people reached.

# Implementation

- Facebook: `FacebookEntry#calculate_views_count` callback before save
- Twitter: Direct from API in `TwitterServices::ProcessPosts`
- Instagram: provider video views in `InstagramServices::ProcessPosts`

# Related

- [FacebookEntry Model](../models/facebook_entry.md) - Facebook views calculation
- [TwitterPost Model](../models/twitter_post.md) - Twitter views data
- [Engagement Metrics](engagement_metrics.md) - Overall engagement rules

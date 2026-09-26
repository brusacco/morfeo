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

Facebook doesn't provide direct view counts, so Morfeo estimates them using an engagement-based formula:

```
views = (likes * 15) + (comments * 40) + (shares * 80) + (followers * 0.04)
```

- Likes weighted at 15 views each
- Comments weighted at 40 views each (higher engagement)
- Shares weighted at 80 views each (highest reach)
- Followers contribute 4% of their count (passive reach)

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

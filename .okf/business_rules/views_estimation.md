---
type: Business Rule
title: Views Estimation
description: Views calculation rules by platform
tags: [views, estimation, calculations, facebook]
timestamp: 2026-09-22T00:00:00Z
---

# Overview

Different platforms provide views data differently. Facebook requires estimation while Twitter provides real view counts.

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

## Twitter (Real Data)

- Twitter API provides actual view counts
- Stored directly in `views_count` field
- No estimation needed

## Instagram

- Instagram API doesn't provide view counts for regular posts
- Views not tracked for Instagram analytics

# Implementation

- Facebook: `FacebookEntry#calculate_views_count` callback before save
- Twitter: Direct from API in `TwitterServices::ProcessPosts`
- Instagram: Not implemented

# Related

- [FacebookEntry Model](../models/facebook_entry.md) - Facebook views calculation
- [TwitterPost Model](../models/twitter_post.md) - Twitter views data
- [Engagement Metrics](engagement_metrics.md) - Overall engagement rules

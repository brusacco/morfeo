---
type: Business Rule
title: Views Estimation
description: Views calculation rules by platform
tags: [views, estimation, calculations, facebook, instagram]
timestamp: 2026-09-26T00:00:00Z
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

### Calibration Evidence

A read-only production analysis on 2026-09-26 evaluated 564,456 Facebook posts
from 80 tracked pages, dated from 2012-10 through 2026-09. It simulated both the
retired v1 formula and the bounded formula above entirely in memory.

- Observed interaction-to-follower rate (ER) had a median of $0.0048\%$, p95 of
  $0.1864\%$, and p99 of $0.8547\%$. Only 1,049 posts ($0.1858\%$) met or
  exceeded the $3\%$ cap, so the cap is a defensive bound rather than a typical
  operating value.
- In the latest six complete/partial months examined (2026-04 through 2026-09),
  median ER was stable between $0.0035\%$ and $0.0055\%$.
- v1 could produce reach equal to $2,418.99\%$ of current followers because it
  added unbounded per-interaction values and content multipliers. The bounded
  formula remains approximately within $1.0002\%$ to $1.3063\%$ of followers.
- Extreme v1 examples estimated 0.7--1.55 million reached people for pages with
  38K--90K followers. These values are the reason v1 must not be restored.
- At a $1\%$ baseline, simulated aggregate reach was 4,578,410,124. Baseline
  changes scale this total nearly linearly. Reducing the ER cap from $3\%$ to
  $2\%$ changed the total by only 294,136, confirming that cap selection has
  little aggregate effect at current ER levels.

### Interpretation and Limits

The $1\%$ baseline, factor $10$, and $3\%$ cap are retained as a conservative,
bounded reporting heuristic. They are not calibrated predictions of Meta reach.
Morfeo has no observed Facebook reach or impressions ground truth in this
dataset, so this analysis cannot prove that the formula predicts actual Facebook
reach. Do not compare the formula to historical `views_count` with MAE or MAPE:
that field is itself a Morfeo-derived estimate, not a provider observation.

`Page#followers` is refreshed from the Facebook page `fan_count` and is not a
per-post follower snapshot. Historical simulations therefore use the current or
periodically refreshed follower count and cannot make time-accurate historical
reach claims.

## Twitter/X (Observed When Available)

- X API positive view counts are stored directly in `views_count`.
- `TwitterServices::ProcessPosts` currently stores both an absent provider view
  field and an observed zero as `0`; `views_count` is non-nullable.
- The General and Home dashboards use an `interactions * 10` fallback when their
  aggregate stored views are zero. That fallback must be classified as
  `fallback_estimate`.
- The current schema cannot distinguish an observed zero from unavailable views.
  Preserve this limitation until a separate provenance/schema redesign can
  represent that distinction safely.

### Production Evidence and Decision

A read-only production calibration on 2026-09-26 found approximately $97.82\%$
positive observed-view coverage for X. That high coverage means provider values
should remain the primary metric wherever available. Simple candidate fallbacks
did not demonstrate a sufficiently better result than the current aggregate
`interactions * 10` fallback, so this analysis made no formula change.

The retained fallback is not validated as an observed X metric. Because the
non-nullable field stores both missing provider data and observed zero as `0`,
the current schema cannot safely target a fallback only to unavailable values.
Any redesign must first add metric provenance or a separate availability signal.

## Instagram (Observed Video Views)

- `video_view_count` is an observed provider field for video posts only. It is a
  video-view count, not unique reach or impressions.
- The ingestion service preserves a missing provider value as `NULL`; a stored
  zero is therefore distinct from a missing value for this field.
- Images, carousels, and sidecars have no applicable video-view metric and must
  not be evaluated as missing observed views.
- `InstagramPost#estimated_reach` is a separate model-derived value
  (`interactions * 10`, multiplied by $1.5$ for video) and must not be presented
  as an observed provider metric.
- The approved interim reporting rule is: use observed provider video views
  where available and show unavailable otherwise. Do not apply a generic
  Instagram fallback estimate.

### Production Evidence and Limits

A read-only production analysis on 2026-09-26 covered 227,762 posts from 63
profiles, dated 2021-10-05 through 2026-09-26. Of all posts, 80,289 (35.25%)
had positive observed video views, 7,216 (3.17%) stored zero, and 140,257
(61.58%) were `NULL`; the latter are predominantly non-video content. Positive
view coverage for video types was 91.68% for `video/clips`, 96.07% for
`GraphVideo/clips`, and 90.70% for `video/igtv`.

The observed-video sample includes 60 profiles but is concentrated: the top
profile accounts for 11.77% of observed-view posts, and the top 10 account for
68.06%. Video views correlate strongly with interactions ($r = 0.8649$), but
1,945 observed-view posts (2.42%) have zero interactions; 480 records have
negative `likes_count + comments_count`. Neither a global interaction multiplier
nor a follower baseline is sufficiently robust for a fallback.

Against positive observed video views, the existing video interaction estimate
had $60.84\%$ WAPE. A median-calibrated interaction multiplier had $92.28\%$
WAPE and a median follower-rate baseline had $97.43\%$ WAPE. The existing model
is not validated by being the least inaccurate of those candidates.

## Cross-Channel Reporting

- Digital reach (`interactions * 3`) is `estimated`.
- Facebook `views_count` is `estimated`; it is derived by `FacebookEntry#calculate_views_count` and is not a Meta-provided reach metric.
- General and Home expose Instagram as `views`, not `reach`. Its observed video
  views are excluded from cross-channel reach totals and reach charts.
- Cross-channel reach totals may still mix observed X views with modeled values.
  They must be flagged as estimated and must not be described as unique people reached.

# Implementation

- Facebook: `FacebookEntry#calculate_views_count` callback before save
- Twitter: Direct from API in `TwitterServices::ProcessPosts`
- Instagram: provider video views in `InstagramServices::ProcessPosts`

### Instagram Reporting Hotfix

On 2026-09-26, General, Home, and the Instagram topic dashboard were aligned to
the observed-video policy. Their set-based `SUM(video_view_count)` aggregates
preserve an all-`NULL` result as unavailable, preserve aggregate zero as an
observed provider value, and do not use `estimated_reach`. User-facing channel
cards and Instagram post details show `Visualizaciones` or `N/D`; the General
PDF no longer labels Instagram video views as reach.

# Related

- [FacebookEntry Model](../models/facebook_entry.md) - Facebook views calculation
- [TwitterPost Model](../models/twitter_post.md) - Twitter views data
- [Engagement Metrics](engagement_metrics.md) - Overall engagement rules
- [FacebookEntry Model](../models/facebook_entry.md) - Persistence and formula owner
- [Page Model](../models/page.md) - Source and temporal limitation of followers
- [InstagramPost Model](../models/instagram_post.md) - Observed video views and fallback limitation
- [InstagramProfile Model](../models/instagram_profile.md) - Follower metadata limitation
- [Metric Calibration Evidence 2026-09-26](metric_calibration_evidence_2026_09_26.md) - Full production datasets, distributions, and model comparisons

# Citations

- Production read-only Rails analysis, 2026-09-26: batched `FacebookEntry.joins(:page)`
  queries with in-memory v1/v2 simulations. No application records were written.
- Historical formula source: Git revision immediately preceding `698f6da`,
  `app/models/facebook_entry.rb`.
- Production read-only Instagram analysis, 2026-09-26: batched
  `InstagramPost.joins(:instagram_profile)` queries and in-memory candidate
  comparisons. No application records were written.
- Production read-only X calibration, 2026-09-26: observed-view coverage and
  simple fallback comparison. No application records were written.

---
type: concept
title: Metric Calibration Evidence 2026-09-26
description: Read-only production statistical reference for Facebook, X, and Instagram exposure metrics
tags: [metrics, analytics, calibration, research, facebook, twitter, instagram]
timestamp: 2026-09-26T00:00:00Z
---

# Purpose

This is the durable quantitative reference for the read-only production analyses
completed on 2026-09-26. Use it when reconsidering an existing metric, evaluating
a fallback, or planning a new empirical study. It records observed data and model
comparisons; it does not turn any estimate into provider ground truth.

All queries were read-only Rails production queries. No records, schema, or
historical values were written.

# Scope Summary

| Channel   | Dataset                                                       | Provider observation available                  | Decision                                                             |
| --------- | ------------------------------------------------------------- | ----------------------------------------------- | -------------------------------------------------------------------- |
| Facebook  | 564,456 posts, 80 pages, 2012-10 to 2026-09                   | No post-level reach/impressions ground truth    | Keep bounded Morfeo V2 as a conservative heuristic                   |
| X         | 501,501 posts; 64 profiles in positive-view cohort, 2024-2026 | Positive `views_count`, but zero is ambiguous   | Keep provider values primary; no fallback change                     |
| Instagram | 227,762 posts, 63 profiles, 2021-10-05 to 2026-09-26          | `video_view_count` for applicable video content | Use observed video views or unavailable; no fallback                 |
| Digital   | No empirical production calibration in this study             | No provider exposure metric evaluated           | `interactions * 3` remains unvalidated and requires a separate study |

# Facebook

## Dataset and Observed Engagement

- Posts: 564,456.
- Pages: 80.
- Date range: 2012-10 through 2026-09.
- The interaction-to-current-follower engagement rate (ER) distribution was:

| Percentile |      ER |
| ---------- | ------: |
| Median     | 0.0048% |
| p95        | 0.1864% |
| p99        | 0.8547% |

Only 1,049 posts (0.1858%) met or exceeded the 3% ER cap. In the latest six
complete or partial months, 2026-04 through 2026-09, median ER was stable from
0.0035% to 0.0055%.

## Formula Simulation

The retained model is:

```
estimated_reach = followers * 0.01 * (1 + 10 * min(ER, 0.03))
estimated_views = estimated_reach * 1.2
```

- Retired v1 reached as much as 2,418.99% of current followers because it had
  unbounded interaction additions and content multipliers.
- V2 stayed approximately between 1.0002% and 1.3063% of current followers.
- Representative v1 extremes were 0.7--1.55 million estimated reached people
  for pages with 38K--90K followers.
- With a 1% baseline, simulated V2 aggregate reach was 4,578,410,124.
- Reducing the ER cap from 3% to 2% reduced that aggregate by 294,136 only.

## Interpretation

Facebook has no observed reach or impressions ground truth in this dataset.
`views_count` is a Morfeo-derived value, not an observation, and must not be used
for MAE/MAPE validation. Page followers come from the current or periodically
refreshed `fan_count`, not historical post-time snapshots.

# X

## Stored-View Coverage

| Production value       |   Count |
| ---------------------- | ------: |
| Total posts            | 501,501 |
| Positive stored views  | 490,547 |
| Stored zero views      |  10,954 |
| Null views             |       0 |
| Positive-view coverage |  97.82% |

`views_count` is non-nullable: ingestion stores both missing provider views and
observed zero as `0`. A zero cannot therefore safely be targeted for estimation.

## Positive-View Cohort

The detailed cohort output contained 490,550 posts from 64 profiles, dated
2024--2026; 165,866 had zero interactions despite positive observed views. This
is three rows higher than the 490,547 positive-count summary above, so future
reproduction should reconcile batch boundaries or timing before comparing the
two counts directly.

| Ratio                    |    p25 |  Median |     p75 |     p90 |     p95 |
| ------------------------ | -----: | ------: | ------: | ------: | ------: |
| Views / followers        | 0.091% |  0.220% |  0.862% |  2.450% |  4.345% |
| Interactions / followers |     0% | 0.0004% | 0.0033% | 0.0253% | 0.0666% |
| Interactions / views     |     0% | 0.3086% | 0.8929% | 1.9704% | 3.0515% |
| Views / interactions     |   75.4 |   157.0 |   318.0 |   580.0 |   813.0 |

Median views/followers were 0.208% in 2025 and 0.223% in 2026. The 2024 cohort
had 58 posts and is not decision-grade.

## Fallback Comparison

| Model                             |   MAE | MdAE |    WAPE |   MdAPE |    Bias |
| --------------------------------- | ----: | ---: | ------: | ------: | ------: |
| Current interactions x 10         | 1,262 |  429 |  89.98% |  96.96% | -89.63% |
| Followers x 0.2203%               | 1,307 |  467 |  93.14% |  85.18% | -39.29% |
| Followers plus bounded engagement | 1,284 |  466 |  91.49% |  83.22% | -37.19% |
| Interactions x 157                | 1,694 |  310 | 120.72% | 100.00% | +62.87% |

The bounded candidate was $F * 0.002203 * (1 + 1000 * min(ER, 0.01))$. It
improved median percentage error but worsened MAE and WAPE. No candidate was a
sufficiently better replacement for the current fallback.

Representative observed cases show why neither interaction nor followers alone
is defensible: 134,499 followers/0 interactions/1 view; 341,992/0/500;
533,861/16,652/4,839,320; 114,435/30,259/18; and 51,515/299/2,323,674.

# Instagram

## Dataset and View Availability

- Posts: 227,762.
- Profiles: 63; all posts had an associated profile and positive followers.
- Date range: 2021-10-05 through 2026-09-26.

| `video_view_count` state |   Posts |  Share |
| ------------------------ | ------: | -----: |
| Positive                 |  80,289 | 35.25% |
| Zero                     |   7,216 |  3.17% |
| `NULL`                   | 140,257 | 61.58% |

Positive-view coverage is high for applicable video content: 78,783 of 85,933
`video/clips` posts (91.68%), 1,417 of 1,475 `GraphVideo/clips` posts (96.07%),
and 78 of 86 `video/igtv` posts (90.70%). Images, carousels, and sidecars do not
have an applicable video-view metric.

## Distribution and Data Quality

- The positive-view sample covered 60 profiles.
- The top profile represented 11.77% of observed-view posts; the top 5, 49.37%;
  the top 10, 68.06%.
- Video views and interactions had correlation $r = 0.8649$.
- 1,945 observed-view posts (2.42%) had zero interactions.
- 480 observed-view records had negative `likes_count + comments_count`.

The negative interaction records are an upstream data-quality issue; this study
did not modify or correct them.

## Fallback Comparison

Evaluated only against positive observed video views:

| Model                           |   WAPE |  MdAPE |    Bias |
| ------------------------------- | -----: | -----: | ------: |
| Existing interactions x 15      | 60.84% | 52.54% |  +1.33% |
| Calibrated interactions x 24.27 | 92.28% | 47.23% | +63.98% |
| Followers x 0.7626%             | 97.43% | 91.26% | -55.10% |

The existing estimate was the least inaccurate candidate, not a validated
fallback. It returns zero for observed-positive-view posts with zero
interactions. Examples include `telefuturo` (1,360,277 followers, 0 interactions,
4,965 views), `elobservadorpy_` (4,825, 1, 3,720), `abcdigital` (1,184,646, 24,
602), and `amambayahora` (81,590, 798,576, 5,773,006).

# Reuse Rules

1. Do not compare results across channels as though all view fields measure the
   same thing: Facebook is modeled, X is mostly observed but has ambiguous zero,
   and Instagram is observed video views only.
2. Re-run analyses with an explicit extraction timestamp, date range, query
   filters, and a reconciliation of cohort counts before changing a formula.
3. Treat the Facebook follower input as temporally mutable; do not construct a
   historical-reach claim from it.
4. Do not use Instagram interaction or follower models as a fallback without new
   provider ground truth and a separate approval.
5. Treat Digital `interactions * 3` as a priority for a separate empirical study,
   not as an outcome validated here.

# Related

- [Views Estimation](views_estimation.md) - Current channel metric policy
- [FacebookEntry Model](../models/facebook_entry.md) - Facebook formula owner
- [TwitterPost Model](../models/twitter_post.md) - X view provenance
- [InstagramPost Model](../models/instagram_post.md) - Instagram video-view field
- [Twitter Aggregator Service](../twitter_reports/aggregator_service.md) - X dashboard aggregation
- [Instagram Aggregator Service](../instagram_reports/aggregator_service.md) - Instagram dashboard aggregation

# Citations

- Read-only production Facebook calibration, 2026-09-26.
- Read-only production X calibration, 2026-09-26.
- Read-only production Instagram analysis, 2026-09-26.

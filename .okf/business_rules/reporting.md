---
type: Business Rule
title: Reporting
description: Report generation and access rules
tags: [reports, pdf, analytics, dashboards]
timestamp: 2026-09-22T00:00:00Z
---

# Overview

Morfeo generates comprehensive analytics dashboards and PDF reports for each topic across all platforms (digital, Facebook, Twitter, Instagram).

# Rules

## Dashboard Access

- Users must be authenticated to view dashboards
- Users can only view topics they're assigned to
- Topics must be enabled (status: true)
- Default date range is 7 days (configurable via `DAYS_RANGE`)

## PDF Report Generation

- Uses Grover gem (Chrome headless) for HTML-to-PDF conversion
- A4 page size with 2cm margins
- Print-optimized layout with page break controls
- Auto-print trigger after 1 second delay
- Charts rendered with Highcharts for print clarity

## Report Content

All platform reports include:

1. Header with topic name and date range
2. KPI statistics (total posts, interactions, views, averages)
3. Temporal evolution charts (posts/day, interactions/day)
4. Tag analysis (distribution and interactions)
5. Source analysis (sites/pages/profiles)
6. Top performing content
7. Word cloud visualization
8. Word/bigram frequency tables

## Platform-Specific Features

- **Digital**: Sentiment analysis, calendar view, comments analysis
- **Facebook**: Reaction breakdown, sentiment labels, controversy index
- **Twitter**: Real view counts, tweet type analysis (retweet/quote)
- **Instagram**: Media type analysis (images/videos/carousels)

## Caching

- Dashboard pages cached for 30 minutes
- Cache key includes topic_id, user_id, and days_range
- Ensures consistent data during viewing session

# Related

- [Digital Reports](../digital_reports/) - Digital media reporting
- [Facebook Reports](../facebook_reports/) - Facebook reporting
- [Twitter Reports](../twitter_reports/) - Twitter reporting
- [Instagram Reports](../instagram_reports/) - Instagram reporting

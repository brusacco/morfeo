---
type: Model
title: TitleTopicStatDaily
description: Same metrics but for title-tag analysis
resource: app/models/title_topic_stat_daily.rb
tags: [analytics, daily, topics, titles]
timestamp: 2026-09-22T00:00:00Z
---

# Overview

The TitleTopicStatDaily model stores daily aggregated metrics for title-tag analysis, separate from content-based topic statistics.

# Schema

| Field             | Type    | Description                    |
| ----------------- | ------- | ------------------------------ |
| topic_id          | integer | Foreign key to Topic           |
| topic_date        | date    | Date of the statistics         |
| entry_count       | integer | Number of entries for the day  |
| interaction_count | integer | Total interactions for the day |
| positive_count    | integer | Positive sentiment entries     |
| negative_count    | integer | Negative sentiment entries     |
| neutral_count     | integer | Neutral sentiment entries      |

# Associations

- `belongs_to :topic` - The topic this statistic is for ([Topic](topic.md))

# Scopes

- `normal_range` - Filter to last DAYS_RANGE days

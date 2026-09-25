---
type: Model
title: Topic
description: Collections of tags for organizing and tracking specific subjects
resource: app/models/topic.rb
tags: [content, core, analytics]
timestamp: 2026-09-22T00:00:00Z
---

# Overview

The Topic model represents collections of tags used to organize and track specific subjects or themes. Topics are the primary unit for analytics and reporting.

# Schema

| Field          | Type    | Description                         |
| -------------- | ------- | ----------------------------------- |
| name           | string  | Topic name                          |
| status         | boolean | enabled/disabled                    |
| positive_words | text    | Words indicating positive sentiment |
| negative_words | text    | Words indicating negative sentiment |

# Associations

- `has_and_belongs_to_many :tags` - Tags that define this topic ([Tag](tag.md))
- `has_many :entries, through: :entry_topics` - Entries matching topic tags ([Entry](entry.md), [EntryTopic](entry_topic.md))
- `has_many :title_entries, through: :entry_title_topics` - Entries matching title tags ([EntryTitleTopic](entry_title_topic.md))
- `has_many :users, through: :user_topics` - Users who can access this topic ([User](user.md), [UserTopic](user_topic.md))
- `has_many :topic_stat_dailies` - Daily analytics for this topic ([TopicStatDaily](topic_stat_daily.md))
- `has_many :title_topic_stat_dailies` - Daily title-tag analytics ([TitleTopicStatDaily](title_topic_stat_daily.md))
- `has_many :reports` - Generated reports ([Report](report.md))
- `has_many :templates` - Report templates ([Template](template.md))

# Key Methods

- `report_entries(start_date, end_date)` - Get entries for reporting period
- `report_title_entries(start_date, end_date)` - Get title-tag entries for reporting
- `list_entries` - Cached list of entries
- `tag_names` - Array of tag names for this topic
- `default_date_range` - Default date range for queries
- `temporal_velocity_aggregates` - Cached entry and interaction totals for temporal velocity

# Temporal Velocity

Velocity compares two adjacent 24-hour periods. The previous period is
`[now - 48.hours, now - 24.hours)` and the recent period is
`[now - 24.hours, now]`; the shared boundary belongs only to the recent period.

Temporal aggregates derive from the topic entry filter without the display-only
site join, tag eager loading, ordering, or an intermediate list of entry IDs.
The tag membership predicate remains an `EXISTS` filter so entries are not
duplicated for topics with multiple matching tags.

# Auto-Sync

When tags are added/removed from a topic, `SyncTopicEntriesJob` is queued to automatically link existing entries with matching tags.

# Related

- [Digital Reports Infrastructure](../digital_reports/) - Digital media analytics for topics
- [Facebook Reports Infrastructure](../facebook_reports/) - Facebook analytics for topics
- [Twitter Reports Infrastructure](../twitter_reports/) - Twitter analytics for topics
- [Instagram Reports Infrastructure](../instagram_reports/) - Instagram analytics for topics
- [Topic Organization](../business_rules/topic_organization.md) - Topic organization rules
- [User Access Control](../business_rules/user_access_control.md) - Topic access rules

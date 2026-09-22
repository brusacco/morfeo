---
type: Model
title: Entry
description: News articles with URL, title, content, sentiment polarity, and social media interaction counts
resource: app/models/entry.rb
tags: [content, core, articles]
timestamp: 2026-09-22T00:00:00Z
---

# Overview

The Entry model represents individual news articles crawled from monitored websites. It's the central content model in Morfeo, linking to social media posts, topics, and analytics.

# Schema

| Field          | Type     | Description                                     |
| -------------- | -------- | ----------------------------------------------- |
| url            | string   | Unique URL of the article                       |
| title          | string   | Article title                                   |
| description    | text     | Article description/summary                     |
| content        | text     | Full article content                            |
| image_url      | string   | URL to article image                            |
| published_at   | datetime | Publication date                                |
| polarity       | enum     | Sentiment: neutral(0), positive(1), negative(2) |
| reaction_count | integer  | Social media reactions                          |
| comment_count  | integer  | Social media comments                           |
| share_count    | integer  | Social media shares                             |
| total_count    | integer  | Total social interactions                       |
| repeated       | enum     | No(0), Si(1), Limpiado(2)                       |
| enabled        | boolean  | Whether entry is active                         |
| category       | string   | Content classification                          |
| site_id        | integer  | Foreign key to Site                             |

# Associations

- `belongs_to :site` - The website this article was crawled from ([Site](site.md))
- `has_many :comments` - Facebook comments on this article ([Comment](comment.md))
- `has_one :twitter_post` - Linked tweet referencing this article ([TwitterPost](twitter_post.md))
- `has_one :facebook_entry` - Linked Facebook post referencing this article ([FacebookEntry](facebook_entry.md))
- `has_many :topics, through: :entry_topics` - Topics this entry belongs to ([Topic](topic.md), [EntryTopic](entry_topic.md))
- `has_many :title_topics, through: :entry_title_topics` - Title-based topic associations ([EntryTitleTopic](entry_title_topic.md))

# Key Methods

- `self.for_topic(topic, start_time:, end_time:)` - Filter entries by topic and date range
- `self.grouped_counts(scope, format)` - Daily entry counts for charts
- `self.grouped_interactions(scope, format)` - Daily interaction totals
- `self.total_interactions(scope)` - Sum of all engagement metrics
- `words` - Tokenize content, filter stop words
- `bigrams` - Extract two-word phrases

# Tagging

Uses `acts-as-taggable-on` with two contexts:

- `:tags` - Content-based tags
- `:title_tags` - Title-only tags

Auto-syncs topic associations when tags change via `after_save` callbacks.

# Related

- [Digital Reports Infrastructure](../digital_reports/) - Analytics dashboard for web articles
- [Content Crawling](../business_rules/content_crawling.md) - Crawling and extraction rules
- [Topic Organization](../business_rules/topic_organization.md) - Topic organization rules
- [Sentiment Analysis](../business_rules/sentiment_analysis.md) - Sentiment analysis rules

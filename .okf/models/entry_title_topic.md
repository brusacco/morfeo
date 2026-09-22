---
type: Model
title: EntryTitleTopic
description: Join model for Entry-Topic title-tag relationship
resource: app/models/entry_title_topic.rb
tags: [join, entries, topics, titles]
timestamp: 2026-09-22T00:00:00Z
---

# Overview

The EntryTitleTopic model is a join model that creates a many-to-many relationship between Entry and Topic based on title tags.

# Schema

| Field    | Type    | Description          |
| -------- | ------- | -------------------- |
| entry_id | integer | Foreign key to Entry |
| topic_id | integer | Foreign key to Topic |

# Associations

- `belongs_to :entry` ([Entry](entry.md))
- `belongs_to :topic` ([Topic](topic.md))

# Validations

- `entry_id` must be unique within scope of `topic_id`

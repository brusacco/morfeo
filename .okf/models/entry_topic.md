---
type: Model
title: EntryTopic
description: Join model for Entry-Topic many-to-many relationship
resource: app/models/entry_topic.rb
tags: [join, entries, topics]
timestamp: 2026-09-22T00:00:00Z
---

# Overview

The EntryTopic model is a join model that creates a many-to-many relationship between Entry and Topic.

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

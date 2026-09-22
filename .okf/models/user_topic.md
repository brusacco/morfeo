---
type: Model
title: UserTopic
description: Join model for User-Topic many-to-many relationship
resource: app/models/user_topic.rb
tags: [join, users, topics]
timestamp: 2026-09-22T00:00:00Z
---

# Overview

The UserTopic model is a join model that creates a many-to-many relationship between User and Topic, enabling topic access control.

# Schema

| Field    | Type    | Description          |
| -------- | ------- | -------------------- |
| user_id  | integer | Foreign key to User  |
| topic_id | integer | Foreign key to Topic |

# Associations

- `belongs_to :user` ([User](user.md))
- `belongs_to :topic` ([Topic](topic.md))

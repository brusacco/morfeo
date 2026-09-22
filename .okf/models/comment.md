---
type: Model
title: Comment
description: Facebook comments with uid, message, linked to entries
resource: app/models/comment.rb
tags: [social, facebook, comments]
timestamp: 2026-09-22T00:00:00Z
---

# Overview

The Comment model stores Facebook comments on entries, enabling sentiment analysis and engagement tracking.

# Schema

| Field    | Type    | Description                |
| -------- | ------- | -------------------------- |
| uid      | string  | Unique Facebook comment ID |
| message  | text    | Comment text               |
| entry_id | integer | Foreign key to Entry       |

# Associations

- `belongs_to :entry` - The entry this comment is on ([Entry](entry.md))

# Key Methods

- `self.word_occurrences(limit)` - Word frequency analysis across all comments
- `self.bigram_occurrences(limit)` - Bigram frequency analysis across all comments

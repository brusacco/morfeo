---
type: Model
title: RecentEntry
description: Recent entries with tagging and word analysis
resource: app/models/recent_entry.rb
tags: [content, recent, analytics]
timestamp: 2026-09-22T00:00:00Z
---

# Overview

The RecentEntry model stores recent entries with tagging capabilities and word/bigram analysis methods.

# Schema

| Field   | Type    | Description         |
| ------- | ------- | ------------------- |
| title   | string  | Entry title         |
| content | text    | Entry content       |
| site_id | integer | Foreign key to Site |

# Associations

- `belongs_to :site` - The site this entry is from ([Site](site.md))
- `acts_as_taggable_on :tags` - Topic tags ([Tag](tag.md))

# Key Methods

- `self.positives` - Get IDs of positive entries
- `self.bigram_occurrences(limit)` - Bigram frequency analysis
- `self.word_occurrences(limit)` - Word frequency analysis

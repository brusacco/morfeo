---
type: Model
title: Tag
description: Labels applied to entries for categorization
resource: app/models/tag.rb
tags: [content, core, tagging]
timestamp: 2026-09-22T00:00:00Z
---

# Overview

The Tag model provides flexible categorization for entries using the `acts-as-taggable-on` gem. Tags are used to organize content and define topics.

# Schema

| Field      | Type   | Description                       |
| ---------- | ------ | --------------------------------- |
| name       | string | Tag name                          |
| variations | string | Comma-separated manual variations |

# Usage

Tags are applied to entries in two contexts:

- `:tags` - Content-based tags (applied to full article content)
- `:title_tags` - Title-only tags (applied to article titles)

# Topic Relationship

Topics are defined as collections of tags. When an entry is tagged with tags that belong to a topic, it's automatically associated with that topic.

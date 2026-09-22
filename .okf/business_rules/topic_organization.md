---
type: Business Rule
title: Topic Organization
description: How content is organized into topics using tags
tags: [topics, tags, organization, categorization]
timestamp: 2026-09-22T00:00:00Z
---

# Overview

Content in Morfeo is organized into Topics, which are collections of Tags. Entries and social posts are automatically linked to topics based on their tags.

# Rules

## Topic Definition

- Topics are defined by collections of tags (many-to-many relationship)
- Topics have a status (enabled/disabled) for active/inactive control
- Topics can have positive and negative sentiment words configured

## Tag Contexts

- Entries use two tag contexts: `:tags` (content-based) and `:title_tags` (title-only)
- Social posts use `:tags` context only
- Tags are applied using the `acts-as-taggable-on` gem

## Automatic Topic Association

- When an entry's tags are saved, it's automatically linked to matching topics
- When a topic's tags are changed, existing entries with matching tags are linked
- Topic entry sync runs as a background job (`SyncTopicEntriesJob`)
- Sync covers entries from the last 60 days

## Topic Access

- Users can only view topics they're assigned to (via UserTopic join model)
- Topic authorization checks both topic status and user assignment
- Unauthorized users are redirected with an alert message

# Related

- [Topic Model](../models/topic.md) - Topic data structure
- [Tag Model](../models/tag.md) - Tag data structure
- [Entry Model](../models/entry.md) - Entry tagging
- [User Access Control](user_access_control.md) - Topic access rules

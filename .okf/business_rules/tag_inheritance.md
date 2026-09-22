---
type: Business Rule
title: Tag Inheritance
description: Social post tag inheritance from linked entries
tags: [tags, inheritance, social, linking]
timestamp: 2026-09-22T00:00:00Z
---

# Overview

When social posts (Facebook, Twitter, Instagram) are linked to news articles (entries), they automatically inherit the entry's tags for consistent topic organization.

# Rules

## Inheritance Process

1. Social post is linked to an entry via URL matching
2. When tagging the social post, the system first searches for tags in the post text
3. If the post has a linked entry, all entry tags are also applied
4. Both tag sources (text matching + entry tags) are combined and deduplicated

## Fallback Inheritance

- If text matching fails but the post is linked to an entry with tags, those tags are inherited anyway
- This ensures linked posts always have proper topic coverage

## Benefits

- Better topic coverage for social posts
- Cross-platform consistency (tweets and articles share tags)
- Reduced manual tagging effort
- Improved analytics accuracy

## Implementation

- Facebook: `WebExtractorServices::ExtractFacebookEntryTags`
- Twitter: `TwitterServices::ExtractTags`
- Instagram: `InstagramServices::ExtractTags`
- Rake tasks use `.includes(:entry)` to prevent N+1 queries

# Related

- [URL Matching](url_matching.md) - How social posts are linked to entries
- [Topic Organization](topic_organization.md) - How tags define topics

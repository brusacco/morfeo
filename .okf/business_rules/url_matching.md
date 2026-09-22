---
type: Business Rule
title: URL Matching
description: Linking social posts to news articles by URL matching
tags: [url, matching, linking, normalization]
timestamp: 2026-09-22T00:00:00Z
---

# Overview

Morfeo automatically links social media posts to news articles by matching URLs extracted from social posts against entry URLs, handling various URL formats and variations.

# Rules

## URL Extraction

- **Facebook**: Extracts URLs from `attachment_target_url` and `attachment_url`
- **Twitter**: Extracts URLs from tweet payload entities (handles Hash, JSON, and Ruby hash string formats)
- **Instagram**: Extracts URLs from post captions and links

## URL Normalization

The system generates URL variations for matching:

- Exact URL
- Without query parameters
- Without trailing slash
- With/without www prefix

## Matching Process

1. Extract URLs from social post
2. For each URL, generate normalized variations
3. Search for Entry records with matching URLs
4. If match found, create association between social post and entry

## Expected Match Rates

- ~99.8% of Facebook posts contain external URLs
- ~16% of Facebook posts with URLs match existing entries
- ~70% of tweets contain external URLs
- ~10% of tweets with URLs match existing entries

## Batch Processing

- `rake facebook:link_to_entries` - Process all unlinked Facebook posts
- `rake twitter:link_to_entries` - Process all unlinked tweets
- Admin UI shows linked/unlinked status with filtering

# Related

- [Tag Inheritance](tag_inheritance.md) - Tags inherited after linking
- [FacebookEntry Model](../models/facebook_entry.md) - Facebook URL extraction
- [TwitterPost Model](../models/twitter_post.md) - Twitter URL extraction

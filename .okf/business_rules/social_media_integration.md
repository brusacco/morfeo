---
type: Business Rule
title: Social Media Integration
description: Platform-specific social media integration rules
tags: [social, facebook, twitter, instagram, integration]
timestamp: 2026-09-22T00:00:00Z
---

# Overview

Morfeo integrates with Facebook, Twitter, and Instagram to track posts from monitored profiles and pages, linking them to news articles for comprehensive analytics.

# Rules

## Facebook Integration

- Tracks Facebook Pages via `Page` model
- Fetches posts with full reaction breakdowns (like, love, wow, haha, sad, angry, thankful)
- Calculates estimated views using engagement formula
- Stores posts as `FacebookEntry` records
- Uses Facebook Graph API v18.0

## Twitter Integration

- Tracks Twitter profiles via `TwitterProfile` model
- Two API approaches: Guest Token (cached) and Authenticated (real-time)
- Authenticated API requires session cookies (`TWITTER_AUTH_TOKEN`, `TWITTER_CT0_TOKEN`)
- Can fetch up to 500 tweets with pagination
- Stores posts as `TwitterPost` records with full payload
- Production stores payloads as Ruby hash strings (`=>` syntax)

## Instagram Integration

- Tracks Instagram profiles via `InstagramProfile` model
- Uses Instagram Graph API
- Requires Instagram Business account
- Downloads post images automatically
- Stores posts as `InstagramPost` records

## Common Rules

- All social posts can be linked to entries via URL matching
- All social posts support topic tagging
- All platforms have dedicated analytics dashboards
- Profile data is automatically updated via API calls

# Related

- [FacebookEntry Model](../models/facebook_entry.md) - Facebook post structure
- [TwitterPost Model](../models/twitter_post.md) - Twitter post structure
- [InstagramPost Model](../models/instagram_post.md) - Instagram post structure
- [URL Matching](url_matching.md) - Linking social posts to entries

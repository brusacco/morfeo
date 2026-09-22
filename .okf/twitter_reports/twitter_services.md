---
type: Service
title: Twitter Services
description: Twitter API integration services for data fetching and processing
resource: app/services/twitter_services/
tags: [twitter, api, service, integration]
timestamp: 2026-09-22T00:00:00Z
---

# Overview

The Twitter services provide integration with the Twitter GraphQL API for fetching profile data, tweets, and engagement metrics.

# Services

## GetPostsData

Retrieves user tweets via Twitter GraphQL API (guest token).

- Returns cached/old data (up to 100 tweets)
- Used as fallback when authenticated API is unavailable

## GetPostsDataAuth

**Authenticated API** using session cookies.

- Fetches fresh real-time tweets with pagination
- Up to 500 tweets across 5 requests
- Requires `TWITTER_AUTH_TOKEN` and `TWITTER_CT0_TOKEN` environment variables

## GetProfileData

Fetches raw Twitter profile information.

## UpdateProfile

Extracts and formats profile data for database storage.

## ProcessPosts

Extracts and persists tweets from Twitter API responses.

- Automatically uses authenticated API when credentials are present
- Parameters: `profile_uid`, `stop_on_duplicates`, `update_existing`
- `stop_on_duplicates: true` (default) - Fast incremental updates
- `stop_on_duplicates: false` - Full archive crawl
- `update_existing: true` - Updates engagement metrics for existing tweets

## ExtractTags

Auto-tags tweets using Tag vocabulary with text matching.

- Includes entry tag inheritance
- Searches for tags in tweet text

## LinkToEntries

Batch service to link TwitterPosts to Entries by matching external URLs.

- Extracts URLs from tweet payload entities
- Matches against Entry URLs
- Creates associations

## AccountManager

Manages multiple Twitter accounts for rotation and rate limit management.

# API Integration

- Uses Twitter GraphQL API
- Two approaches: Guest Token API and Authenticated API
- Handles pagination and rate limiting
- Error handling with retry logic

# Authentication

- `TWITTER_AUTH_TOKEN` - Session auth_token cookie
- `TWITTER_CT0_TOKEN` - CSRF token (ct0 cookie)
- `TWITTER_BEARER_TOKEN` - Bearer token (optional)
- Session cookies expire after 30-90 days

# Related

- [TwitterPost Model](../models/twitter_post.md) - Stores fetched tweets
- [TwitterProfile Model](../models/twitter_profile.md) - Stores profile data
- [Twitter Reports Infrastructure](../twitter_reports/) - Analytics dashboard

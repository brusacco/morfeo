---
type: Service
title: Instagram Services
description: Instagram API integration services for data fetching and processing
resource: app/services/instagram_services/
tags: [instagram, api, service, integration]
timestamp: 2026-09-22T00:00:00Z
---

# Overview

The Instagram services provide integration with the Instagram Graph API for fetching profile data, posts, and engagement metrics.

# Services

## GetProfileData

Fetches raw Instagram profile information.

## UpdateProfile

Extracts and formats profile data for database storage.

## GetPostsData

Retrieves user posts via Instagram Graph API.

## ProcessPosts

Extracts and persists posts from Instagram API responses.

- Downloads post images
- Handles media types (images, videos, carousels)
- Stores posts as InstagramPost records

## ExtractTags

Auto-tags posts using Tag vocabulary with text matching.

- Searches for tags in post captions
- Includes entry tag inheritance

# API Integration

- Uses Instagram Graph API
- Requires Instagram access token
- Handles pagination and rate limiting
- Error handling with retry logic

# Authentication

- Requires Instagram Business account
- Access token obtained via Facebook Login
- Token refresh handled by Facebook API

# Related

- [InstagramPost Model](../models/instagram_post.md) - Stores fetched posts
- [InstagramProfile Model](../models/instagram_profile.md) - Stores profile data
- [Instagram Reports Infrastructure](../instagram_reports/) - Analytics dashboard

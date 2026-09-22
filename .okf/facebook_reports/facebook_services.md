---
type: Service
title: Facebook Services
description: Facebook API integration services for data fetching and processing
resource: app/services/facebook_services/
tags: [facebook, api, service, integration]
timestamp: 2026-09-22T00:00:00Z
---

# Overview

The Facebook services provide integration with the Facebook Graph API for fetching page data, posts, comments, and engagement metrics.

# Services

## FanpageCrawler

Crawls Facebook posts from tracked Pages with full engagement metrics.

- Fetches posts with reaction breakdowns
- Calculates estimated views
- Stores posts as FacebookEntry records

## UpdatePage

Updates Facebook page metadata.

- Fetches page name, username, followers
- Updates category and description
- Syncs profile picture

## CommentCrawler

Fetches comments from specific Facebook posts.

- Retrieves comment text and metadata
- Stores as Comment records

## UpdateStats

Updates engagement statistics for Entry URLs via Facebook Graph API.

- Fetches reaction counts for URLs
- Updates Entry social metrics

## LinkToEntries

Batch service to link FacebookEntries to Entries by matching external URLs.

- Extracts URLs from Facebook posts
- Matches against Entry URLs
- Creates associations

# API Integration

- Uses Facebook Graph API v18.0
- Requires Facebook access token
- Handles pagination and rate limiting
- Error handling with retry logic

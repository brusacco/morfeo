---
type: concept
title: API
description: REST API v1 endpoints for entries, sites, tags, and topics with authentication and response formats
tags:
  - api
  - rest
  - endpoints
  - authentication
---

# API

Morfeo exposes a REST API at `/api/v1/` for programmatic access to entries, sites, tags, and topics.

## Endpoints

### Topics

- `GET /api/v1/topics` - List topics
- `GET /api/v1/topics/:id` - Show topic details

### Sites

- `GET /api/v1/sites` - List monitored sites
- `GET /api/v1/sites/:id` - Show site details

### Tags

- `GET /api/v1/tags` - List tags
- `GET /api/v1/tags/:id` - Show tag details

### Entries

- `GET /api/v1/entries` - List entries with filtering
- `GET /api/v1/entries/:id` - Show entry details

## Authentication

API authentication uses [describe auth mechanism - check API controllers].

## Response Format

All endpoints return JSON responses with consistent structure:

```json
{
  "data": { ... },
  "meta": {
    "page": 1,
    "per_page": 25,
    "total": 100
  }
}
```

## Error Handling

Errors return appropriate HTTP status codes with JSON error objects:

```json
{
  "error": "not_found",
  "message": "Resource not found"
}
```

## Rate Limiting

[Document rate limiting if applicable]

## OpenAPI Specification

The API specification is available at `/openapi.yaml`.

# External APIs Used

Morfeo integrates with several external APIs for data collection and processing.

## Facebook Graph API

**Base URL**: `https://graph.facebook.com`
**Version**: `v22.0`
**Authentication**: `FACEBOOK_API_TOKEN` environment variable

### Endpoints Used

- `GET /{version}/{page_id}/posts` - Fetch posts from a Facebook page
- `GET /{version}/{post_id}/comments` - Fetch comments for a post
- `GET /{version}/{page_id}` - Fetch page information
- `GET /{version}/{post_id}` - Fetch post statistics

### Services Using This API

- `FacebookServices::FanpageCrawler` - Crawls Facebook pages for posts
- `FacebookServices::CommentCrawler` - Crawls comments on posts
- `FacebookServices::UpdatePage` - Updates page information
- `FacebookServices::UpdateStats` - Updates post statistics

### Rate Limiting

- Default wait time: 60 seconds when rate limited
- Error codes handled: 4, 17, 32, 613
- Max retries: 3 with exponential backoff

## Twitter/X API

**Base URL**: `https://api.x.com`
**Authentication**: Bearer token + Guest token

### Endpoints Used

- `POST /1.1/guest/activate.json` - Activate guest session
- `GET /graphql/E8Wq-_jFSaU7hxVcuOPR9g/UserTweets` - Fetch user tweets via GraphQL

### Services Using This API

- `TwitterServices::GetPostsData` - Fetches tweets for a user
- `TwitterServices::GetProfileData` - Fetches user profile information
- `TwitterServices::GetPostsDataAuth` - Authenticated tweet fetching via proxy

### Authentication Flow

1. Obtain guest token via `/1.1/guest/activate.json`
2. Use guest token with Bearer token for API requests
3. Guest tokens expire and must be refreshed periodically

## Influencers API (Instagram)

**Base URL**: `https://www.influencers.com.py/api/v1`
**Authentication**: `INFLUENCERS_TOKEN` environment variable

### Endpoints Used

- `GET /profiles/{username}?token={token}` - Fetch Instagram profile data
- `GET /posts/{username}?token={token}` - Fetch Instagram posts data

### Services Using This API

- `InstagramServices::GetProfileData` - Fetches Instagram profile information
- `InstagramServices::GetPostsData` - Fetches Instagram posts
- `InstagramServices::UpdateProfile` - Updates profile information
- `InstagramServices::ProcessPosts` - Processes fetched posts

## Scrape.do API

**Base URL**: `https://api.scrape.do`
**Authentication**: `SCRAPE_DO_API_TOKEN` environment variable

### Endpoints Used

- `GET /?token={token}&url={url}&...` - Fetch URL through proxy with options

### Services Using This API

- `ProxyCrawlerServices::ProxyClient` - Primary proxy client for all proxy crawling
- `HeadlessCrawlerServices::BrowserManager` - Fallback for Cloudflare-protected sites
- `TwitterServices::GetPostsDataAuth` - Twitter API access through proxy

### Features Used

- JavaScript rendering
- Cloudflare bypass
- Custom headers
- Wait for selectors
- Timeout configuration (90 seconds)

### Retry Logic

- Max retries: 3
- Exponential backoff (2s, 4s, 8s)
- Request timeout: 90 seconds

## HTTP Client Libraries

Morfeo uses the following HTTP client libraries:

- **HTTParty** - Primary HTTP client for all API requests
- **Open-uri** - Used for simple URL fetching (Facebook)
- **Selenium WebDriver** - For headless browser automation

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
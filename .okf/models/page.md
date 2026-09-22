---
type: Model
title: Page
description: Facebook page metadata with follower counts and descriptions
resource: app/models/page.rb
tags: [social, facebook, profiles]
timestamp: 2026-09-22T00:00:00Z
---

# Overview

The Page model stores metadata for Facebook Pages being tracked, including follower counts and descriptions.

# Schema

| Field       | Type    | Description                  |
| ----------- | ------- | ---------------------------- |
| uid         | string  | Unique Facebook Page ID      |
| name        | string  | Page name                    |
| username    | string  | Page username                |
| followers   | integer | Follower count               |
| description | text    | Page description             |
| category    | string  | Page category                |
| picture     | string  | Page picture URL             |
| site_id     | integer | Optional foreign key to Site |

# Associations

- `belongs_to :site, optional: true` - Associated website ([Site](site.md))
- `has_many :facebook_entries` - Posts from this page ([FacebookEntry](facebook_entry.md))

# Key Methods

- `update_from_api` - Update page metadata from Facebook Graph API

# Related

- [Facebook Reports Infrastructure](../facebook_reports/) - Analytics dashboard for Facebook posts
- [Facebook Services](../facebook_reports/facebook_services.md) - API integration services

---
type: Model
title: Site
description: News websites being monitored with crawling configuration
resource: app/models/site.rb
tags: [content, core, crawling]
timestamp: 2026-09-22T00:00:00Z
---

# Overview

The Site model represents news websites that Morfeo monitors and crawls. Each site has configuration for how to extract content and filter results.

# Schema

| Field           | Type    | Description                                |
| --------------- | ------- | ------------------------------------------ |
| name            | string  | Unique site name                           |
| url             | string  | Unique site URL                            |
| filter          | string  | Inclusion filter pattern                   |
| negative_filter | string  | Exclusion filter pattern                   |
| content_filter  | string  | CSS selector for content extraction        |
| status          | boolean | enabled/disabled                           |
| is_js           | boolean | Requires Selenium for JavaScript rendering |
| entries_count   | integer | Cached count of entries                    |
| image64         | text    | Base64-encoded logo image                  |

# Associations

- `has_many :entries` - Articles crawled from this site ([Entry](entry.md))
- `has_one :page` - Associated Facebook page ([Page](page.md))
- `has_one :twitter_profile` - Associated Twitter profile ([TwitterProfile](twitter_profile.md))
- `has_one :instagram_profile` - Associated Instagram profile ([InstagramProfile](instagram_profile.md))
- `has_many :newspaper` - Newspaper archival records ([Newspaper](newspaper.md))

# Key Methods

- `save_image(url)` - Download and store site logo as Base64
- `image` - Generate image tag for display

# Scopes

- `enabled` - Active sites
- `disabled` - Inactive sites
- `js_site` - Sites requiring JavaScript rendering
- `entry_none` - Enabled sites with no entries

# Related

- [Content Crawling](../business_rules/content_crawling.md) - Crawling and site configuration rules

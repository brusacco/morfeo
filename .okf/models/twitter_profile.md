---
type: Model
title: TwitterProfile
description: Twitter account tracking with profile data and metrics
resource: app/models/twitter_profile.rb
tags: [social, twitter, profiles]
timestamp: 2026-09-22T00:00:00Z
---

# Overview

The TwitterProfile model tracks Twitter accounts being monitored, storing profile data and metrics.

# Schema

| Field       | Type    | Description                  |
| ----------- | ------- | ---------------------------- |
| uid         | string  | Unique Twitter User ID       |
| username    | string  | Twitter username             |
| name        | string  | Display name                 |
| picture     | string  | Profile picture URL          |
| followers   | integer | Follower count               |
| description | text    | Bio/description              |
| verified    | boolean | Verified account status      |
| site_id     | integer | Optional foreign key to Site |

# Associations

- `belongs_to :site, optional: true` - Associated website ([Site](site.md))
- `has_many :twitter_posts` - Tweets from this profile ([TwitterPost](twitter_post.md))

# Key Methods

- `update_from_api` - Manually update profile data from Twitter API
- `update_attributes` - Auto-update after creation
- `update_site_image` - Sync profile picture to associated site

# Auto-Updates

Profile data is automatically updated via `TwitterServices::UpdateProfile` after creation and can be manually refreshed from the admin interface.

# Related

- [Twitter Reports Infrastructure](../twitter_reports/) - Analytics dashboard for Twitter posts
- [Twitter Services](../twitter_reports/twitter_services.md) - API integration services

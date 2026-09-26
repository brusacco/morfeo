---
type: Model
title: InstagramProfile
description: Instagram account tracking with profile data and metrics
resource: app/models/instagram_profile.rb
tags: [social, instagram, profiles]
timestamp: 2026-09-26T00:00:00Z
---

# Overview

The InstagramProfile model tracks Instagram accounts being monitored, storing profile data and engagement metrics.

# Schema

| Field                    | Type     | Description                  |
| ------------------------ | -------- | ---------------------------- |
| uid                      | string   | Instagram user ID            |
| username                 | string   | Instagram username (unique)  |
| name                     | string   | Display name                 |
| picture                  | string   | Profile picture URL          |
| followers                | integer  | Follower count               |
| following                | integer  | Following count              |
| total_posts              | integer  | Total post count             |
| total_interactions_count | integer  | Total interactions           |
| engagement_rate          | float    | Calculated engagement rate   |
| is_verified              | boolean  | Verified status              |
| is_business_account      | boolean  | Business account status      |
| is_private               | boolean  | Private account status       |
| last_synced_at           | datetime | Last sync timestamp          |
| site_id                  | integer  | Optional foreign key to Site |

`followers` is refreshed by `InstagramServices::UpdateProfile` from provider
profile data. It is mutable profile metadata, not a historical follower snapshot
stored with each post; historical views-per-follower calculations therefore are
descriptive only and cannot establish an at-publication reach rate.

# Associations

- `belongs_to :site, optional: true` - Associated website ([Site](site.md))
- `has_many :instagram_posts` - Posts from this profile ([InstagramPost](instagram_post.md))
- `acts_as_taggable_on :tags` - Topic tags ([Tag](tag.md))

# Key Methods

- `calculate_engagement_rate` - Calculate engagement rate
- `instagram_url` - Generate profile URL
- `needs_sync?` - Check if profile needs syncing
- `incomplete?` - Check if profile data is incomplete

# Related

- [Instagram Reports Infrastructure](../instagram_reports/) - Analytics dashboard for Instagram posts
- [Instagram Services](../instagram_reports/instagram_services.md) - API integration services
- [Views Estimation](../business_rules/views_estimation.md) - Follower-based fallback limitation

# Citations

- Production read-only Instagram analysis, 2026-09-26.

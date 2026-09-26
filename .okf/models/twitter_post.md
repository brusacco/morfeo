---
type: Model
title: TwitterPost
description: Individual tweets from tracked Twitter profiles with engagement metrics
resource: app/models/twitter_post.rb
tags: [social, twitter, analytics]
timestamp: 2026-09-26T00:00:00Z
---

# Overview

The TwitterPost model stores individual tweets from tracked Twitter profiles with full engagement metrics from the Twitter API.

# Schema

| Field              | Type     | Description                                                                                              |
| ------------------ | -------- | -------------------------------------------------------------------------------------------------------- |
| tweet_id           | string   | Unique Twitter tweet ID                                                                                  |
| posted_at          | datetime | Tweet publication date                                                                                   |
| text               | text     | Tweet text content                                                                                       |
| permalink_url      | string   | URL to the tweet                                                                                         |
| lang               | string   | Tweet language                                                                                           |
| source             | string   | Tweet source (app/website)                                                                               |
| favorite_count     | integer  | Like/heart count                                                                                         |
| retweet_count      | integer  | Retweet count                                                                                            |
| reply_count        | integer  | Reply count                                                                                              |
| quote_count        | integer  | Quote tweet count                                                                                        |
| views_count        | integer  | Provider view count when positive; `0` ambiguously represents observed zero or unavailable provider data |
| bookmark_count     | integer  | Bookmark count                                                                                           |
| is_retweet         | boolean  | Whether this is a retweet                                                                                |
| is_quote           | boolean  | Whether this is a quote tweet                                                                            |
| payload            | json     | Full JSON response from Twitter API                                                                      |
| twitter_profile_id | integer  | Foreign key to TwitterProfile                                                                            |
| entry_id           | integer  | Optional foreign key to Entry                                                                            |

# Payload Format

**Critical**: Production stores payloads as Ruby hash strings (`=>` syntax), not JSON (`:` syntax). The `external_urls` method handles three formats: Hash objects, JSON strings, and Ruby hash strings.

# Key Methods

- `self.for_topic(topic, start_time:, end_time:)` - Filter by topic and date range
- `self.grouped_counts(scope, format)` - Daily tweet counts
- `self.grouped_interactions(scope, format)` - Daily interaction totals
- `self.total_interactions(scope)` - Sum of all engagement
- `self.total_views(scope)` - Sum of view counts
- `self.word_occurrences(scope, limit)` - Word frequency analysis
- `self.bigram_occurrences(scope, limit)` - Bigram frequency analysis
- `find_matching_entry` - Find Entry with matching URL
- `link_to_entry!` - Create association with Entry
- `external_urls` - Extract URLs from tweet entities
- `tweet_url` - Generate Twitter permalink

# Associations

- `belongs_to :twitter_profile` - The Twitter profile that posted this ([TwitterProfile](twitter_profile.md))
- `belongs_to :entry, optional: true` - Linked news article (if URL matches) ([Entry](entry.md))
- `acts_as_taggable_on :tags` - Topic tags ([Tag](tag.md))

# Twitter API Integration

- Uses Twitter GraphQL API for data fetching
- Two approaches: Guest Token API (cached data) and Authenticated API (real-time)
- Authenticated API requires `TWITTER_AUTH_TOKEN` and `TWITTER_CT0_TOKEN` environment variables
- Can fetch up to 500 tweets with pagination

# View Provenance

`TwitterServices::ProcessPosts` stores a positive provider view value directly,
but writes `0` both when the provider field is absent and when it reports zero.
`views_count` is therefore observed only when positive; its zero value has
ambiguous provenance. Production calibration found approximately $97.82\%$
positive observed-view coverage and did not establish a sufficiently superior
simple fallback. Keep provider values primary and preserve the existing fallback
until a separate schema/provenance redesign can distinguish unavailable from
observed-zero views.

# Related

- [Twitter Reports Infrastructure](../twitter_reports/) - Analytics dashboard for Twitter posts
- [Twitter Services](../twitter_reports/twitter_services.md) - API integration services
- [Social Media Integration](../business_rules/social_media_integration.md) - Twitter integration rules
- [URL Matching](../business_rules/url_matching.md) - Linking tweets to entries
- [Engagement Metrics](../business_rules/engagement_metrics.md) - Twitter engagement calculations
- [Views Estimation](../business_rules/views_estimation.md) - Observed views and fallback decision

# Citations

- Production read-only X calibration, 2026-09-26.

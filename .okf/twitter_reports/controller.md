---
type: Controller
title: TwitterTopicController
description: Handles Twitter topic analytics display, data aggregation, and PDF report generation
resource: app/controllers/twitter_topic_controller.rb
tags: [twitter, reports, controller, analytics]
timestamp: 2026-09-22T00:00:00Z
---

# Overview

The TwitterTopicController manages the Twitter analytics dashboard, providing topic-based filtering, real-time data aggregation, and PDF report generation. It follows the same architectural pattern as the Facebook and Entry topic controllers.

# Actions

## show

Main analytics dashboard displaying all KPIs and visualizations for a topic's Twitter posts.

- Authenticates user and authorizes topic access
- Uses `TwitterDashboardServices::AggregatorService` to load all data
- Assigns data to instance variables for the view
- Caches results for 30 minutes

## entries_data

AJAX endpoint for date-specific drill-down data.

- Accepts `date` parameter (format: DD/MM/YYYY)
- Returns Twitter posts from that specific date
- Renders `_chart_entries.html.erb` partial
- Handles errors gracefully with Spanish error messages

## pdf

Generates PDF report with print-optimized layout.

- Uses `TwitterDashboardServices::AggregatorService` with PDF-specific limits
- Renders `pdf.html.erb` template without layout
- Supports custom date range via `days_range` parameter

# Constants

- `TOP_POSTS_SHOW_LIMIT = 20` - Max posts shown in web view
- `TOP_POSTS_PDF_LIMIT = 10` - Max posts in PDF report
- `TAG_LIMIT = 20` - Max tags displayed
- `SITE_LIMIT = 12` - Max sites displayed
- `CACHE_DURATION = 30.minutes` - Cache expiration

# Data Assignment Methods

The controller uses dedicated methods to assign service data to instance variables:

- `assign_twitter_data` - Core Twitter analytics data
- `assign_profiles_data` - Profile-level analytics
- `assign_temporal_intelligence` - Time-based insights

# Authorization

Uses `TopicAuthorizable` concern with `authorize_topic_access!` before action to ensure users can only view topics they're assigned to.

# Related

- [Twitter Topic Views](views.md) - Dashboard and PDF templates
- [Aggregator Service](aggregator_service.md) - Data aggregation service
- [PDF Service](pdf_service.md) - PDF generation service
- [Topic Model](../models/topic.md) - Topic entity
- [TwitterPost Model](../models/twitter_post.md) - Twitter post entity

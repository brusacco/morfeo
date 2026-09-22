---
type: Controller
title: InstagramTopicController
description: Handles Instagram topic analytics display, data aggregation, and PDF report generation
resource: app/controllers/instagram_topic_controller.rb
tags: [instagram, reports, controller, analytics]
timestamp: 2026-09-22T00:00:00Z
---

# Overview

The InstagramTopicController manages the Instagram analytics dashboard, providing topic-based filtering, real-time data aggregation, and PDF report generation. It follows the same architectural pattern as the Facebook and Twitter topic controllers.

# Actions

## show

Main analytics dashboard displaying all KPIs and visualizations for a topic's Instagram posts.

- Authenticates user and authorizes topic access
- Uses `InstagramDashboardServices::AggregatorService` to load all data
- Assigns data to instance variables for the view
- Caches results for 30 minutes

## entries_data

AJAX endpoint for date-specific drill-down data.

- Accepts `date` parameter (format: DD/MM/YYYY)
- Returns Instagram posts from that specific date
- Renders `_chart_entries.html.erb` partial
- Handles errors gracefully with Spanish error messages

## pdf

Generates PDF report with print-optimized layout.

- Uses `InstagramDashboardServices::AggregatorService` with PDF-specific limits
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

- `assign_instagram_data` - Core Instagram analytics data
- `assign_profiles_data` - Profile-level analytics
- `assign_temporal_intelligence` - Time-based insights

# Authorization

Uses `TopicAuthorizable` concern with `authorize_topic_access!` before action to ensure users can only view topics they're assigned to.

# Related

- [Instagram Topic Views](views.md) - Dashboard and PDF templates
- [Aggregator Service](aggregator_service.md) - Data aggregation service
- [Topic Model](../models/topic.md) - Topic entity
- [InstagramPost Model](../models/instagram_post.md) - Instagram post entity

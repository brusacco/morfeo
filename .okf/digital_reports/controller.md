---
type: Controller
title: TopicController
description: Handles digital media topic analytics display, data aggregation, and PDF report generation
resource: app/controllers/topic_controller.rb
tags: [digital, reports, controller, analytics, entries]
timestamp: 2026-09-22T00:00:00Z
---

# Overview

The TopicController manages the digital media analytics dashboard for web articles (entries). It provides topic-based filtering, real-time data aggregation, sentiment analysis, and PDF report generation. This is the original and most feature-rich topic controller.

# Actions

## show

Main analytics dashboard displaying all KPIs and visualizations for a topic's entries.

- Authenticates user and authorizes topic access
- Uses `DigitalDashboardServices::AggregatorService` to load all data
- Assigns data to instance variables for the view
- Caches results for 30 minutes

## entries_data

AJAX endpoint for date-specific drill-down data with advanced filtering.

- Accepts `date`, `polarity`, and `title` parameters
- Returns entries from that specific date with optional polarity filter
- Supports both content tags and title tags
- Renders `home/chart_entries` partial
- Handles errors gracefully with Spanish error messages

## pdf

Generates PDF report with print-optimized layout.

- Uses `DigitalDashboardServices::PdfService` for data loading
- Renders `pdf.html.erb` template without layout
- Supports custom date range via `days_range` parameter

## comments

Displays Facebook comments for entries in the topic.

- Loads all comments for topic entries
- Performs word occurrence analysis on comments
- Uses TextMood for sentiment analysis

## history

Shows report history for the topic.

- Lists last 20 reports with text
- Ordered by creation date (newest first)

# Constants

- `CACHE_DURATION = 30.minutes` - Cache expiration

# Data Assignment Methods

The controller uses dedicated methods to assign service data to instance variables:

- `assign_topic_data` - Core topic analytics data
- `assign_chart_data` - Chart data for visualizations
- `assign_percentages` - Percentage breakdowns
- `assign_tags_and_words` - Tag and word frequency data
- `assign_temporal_intelligence` - Time-based insights

# Authorization

Uses `TopicAuthorizable` concern with `authorize_topic_access!` before action to ensure users can only view topics they're assigned to.

# Related

- [Digital Topic Views](views.md) - Dashboard and PDF templates
- [Aggregator Service](aggregator_service.md) - Data aggregation service
- [PDF Service](pdf_service.md) - PDF generation service
- [Topic Model](../models/topic.md) - Topic entity
- [Entry Model](../models/entry.md) - Entry entity

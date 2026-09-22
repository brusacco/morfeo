---
type: View
title: Twitter Topic Views
description: Dashboard views and PDF templates for Twitter analytics
resource: app/views/twitter_topic/
tags: [twitter, reports, views, templates]
timestamp: 2026-09-22T00:00:00Z
---

# Overview

The Twitter topic views provide a comprehensive analytics dashboard with multiple visualization components and a print-optimized PDF report template.

# Main Views

## show.html.erb

Main analytics dashboard with 9 sections:

1. **Header** - Topic name, breadcrumbs, PDF generation button
2. **KPI Cards** - Total posts, interactions, views, average interactions
3. **Temporal Charts** - Posts/day and interactions/day column charts
4. **Tag Analysis** - Tag distribution and interaction pie charts
5. **Word Cloud** - Visual word frequency with sentiment coloring
6. **Word/Bigram Lists** - Frequency tables
7. **Profile Distribution** - Posts and interactions by Twitter profile
8. **DataTables** - Sortable/searchable table of all posts
9. **Top Posts Grid** - Visual cards of top performing posts

## pdf.html.erb

Print-optimized report layout for PDF generation:

- A4 page size with 2cm margins
- Page break controls
- Print-specific font sizes
- Chart sizing optimized for print
- Auto-print JavaScript trigger

# Partials

## \_twitter_post.html.erb

Individual Twitter post card displaying:

- Profile name and username
- Tweet text with link
- Engagement metrics (favorites, retweets, replies, views)
- Tags

## \_twitter_posts.html.erb

Grid container for Twitter post cards (3-column responsive layout)

## \_posts_table.html.erb

DataTables implementation with:

- Spanish localization
- 9 columns (date, tweet, tags, profile, favorites, retweets, replies, views, total)
- Custom Tailwind styling
- Pagination and search

## \_chart_entries.html.erb

Date-specific drill-down data rendered via AJAX

## \_temporal_intelligence.html.erb

Time-based insights including:

- Optimal posting times
- Trend velocity
- Peak hours and days
- Heatmap data

## \_tag_insights.html.erb

Tag-based analytics and insights

## \_profile_insights.html.erb

Profile-level performance insights

# Chart Integration

Uses Chartkick with Highcharts adapter for:

- Column charts (temporal data)
- Pie/donut charts (distributions)
- Click handlers for date drill-down

# Styling

- Primary color: Sky blue (`bg-sky-600`)
- Engagement colors: Red (favorites), Green (retweets), Blue (replies)
- Responsive design with Tailwind CSS
- Custom DataTables pagination styling

# Related

- [TwitterTopicController](controller.md) - Controller that renders these views
- [Aggregator Service](aggregator_service.md) - Provides data for the views
- [PDF Service](pdf_service.md) - Generates PDF reports

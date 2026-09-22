---
type: View
title: Facebook Topic Views
description: Dashboard views and PDF templates for Facebook analytics
resource: app/views/facebook_topic/
tags: [facebook, reports, views, templates]
timestamp: 2026-09-22T00:00:00Z
---

# Overview

The Facebook topic views provide a comprehensive analytics dashboard with multiple visualization components and a print-optimized PDF report template.

# Main Views

## show.html.erb

Main analytics dashboard with 9 sections:

1. **Header** - Topic name, breadcrumbs, PDF generation button
2. **KPI Cards** - Total posts, interactions, views, average interactions
3. **Temporal Charts** - Posts/day and interactions/day column charts
4. **Tag Analysis** - Tag distribution and interaction pie charts
5. **Word Cloud** - Visual word frequency with sentiment coloring
6. **Word/Bigram Lists** - Frequency tables
7. **Page Distribution** - Posts and interactions by Facebook Page
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

## \_facebook_entry.html.erb

Individual Facebook post card displaying:

- Page name and username
- Post message with link
- Engagement metrics (reactions, comments, shares, views)
- Tags

## \_facebook_entries.html.erb

Grid container for Facebook post cards (3-column responsive layout)

## \_posts_table.html.erb

DataTables implementation with:

- Spanish localization
- 9 columns (date, post, tags, page, reactions, comments, shares, views, total)
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

## \_page_insights.html.erb

Page-level performance insights

# Chart Integration

Uses Chartkick with Highcharts adapter for:

- Column charts (temporal data)
- Pie/donut charts (distributions)
- Click handlers for date drill-down

# Styling

- Primary color: Blue (`bg-blue-600`)
- Reaction colors: Blue (like), Red (love), Yellow (haha), etc.
- Responsive design with Tailwind CSS
- Custom DataTables pagination styling

# Related

- [FacebookTopicController](controller.md) - Controller that renders these views
- [Aggregator Service](aggregator_service.md) - Provides data for the views
- [PDF Service](pdf_service.md) - Generates PDF reports

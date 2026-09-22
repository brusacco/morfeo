---
type: View
title: Instagram Topic Views
description: Dashboard views and PDF templates for Instagram analytics
resource: app/views/instagram_topic/
tags: [instagram, reports, views, templates]
timestamp: 2026-09-22T00:00:00Z
---

# Overview

The Instagram topic views provide a comprehensive analytics dashboard with multiple visualization components and a print-optimized PDF report template.

# Main Views

## show.html.erb

Main analytics dashboard with 9 sections:

1. **Header** - Topic name, breadcrumbs, PDF generation button
2. **KPI Cards** - Total posts, interactions, views, average interactions
3. **Temporal Charts** - Posts/day and interactions/day column charts
4. **Tag Analysis** - Tag distribution and interaction pie charts
5. **Word Cloud** - Visual word frequency with sentiment coloring
6. **Word/Bigram Lists** - Frequency tables
7. **Profile Distribution** - Posts and interactions by Instagram profile
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

## \_instagram_post.html.erb

Individual Instagram post card displaying:

- Profile name and username
- Post caption with link
- Engagement metrics (likes, comments)
- Tags

## \_instagram_posts.html.erb

Grid container for Instagram post cards (3-column responsive layout)

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

- Primary color: Pink/Purple gradient (Instagram branding)
- Engagement colors: Red (likes), Blue (comments)
- Responsive design with Tailwind CSS
- Custom DataTables pagination styling

# Related

- [InstagramTopicController](controller.md) - Controller that renders these views
- [Aggregator Service](aggregator_service.md) - Provides data for the views

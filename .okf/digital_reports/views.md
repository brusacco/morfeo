---
type: View
title: Digital Topic Views
description: Dashboard views and PDF templates for digital media analytics
resource: app/views/topic/
tags: [digital, reports, views, templates, entries]
timestamp: 2026-09-22T00:00:00Z
---

# Overview

The digital topic views provide a comprehensive analytics dashboard with multiple visualization components, sentiment analysis, and a print-optimized PDF report template.

# Main Views

## show.html.erb

Main analytics dashboard with extensive sections:

1. **Header** - Topic name, breadcrumbs, PDF generation button
2. **KPI Cards** - Total entries, interactions, sentiment breakdown
3. **Temporal Charts** - Entries/day and interactions/day column charts
4. **Sentiment Analysis** - Positive/negative/neutral distribution
5. **Tag Analysis** - Tag distribution and interaction pie charts
6. **Word Cloud** - Visual word frequency with sentiment coloring
7. **Word/Bigram Lists** - Frequency tables
8. **Site Distribution** - Entries and interactions by news site
9. **DataTables** - Sortable/searchable table of all entries
10. **Top Entries Grid** - Visual cards of top performing entries
11. **Calendar View** - Calendar visualization of entry distribution

## pdf.html.erb

Print-optimized report layout for PDF generation:

- A4 page size with 2cm margins
- Page break controls
- Print-specific font sizes
- Chart sizing optimized for print
- Auto-print JavaScript trigger
- Comprehensive sections matching web view

# Partials

## \_temporal_intelligence.html.erb

Time-based insights including:

- Optimal posting times
- Trend velocity
- Peak hours and days
- Heatmap data

## \_tag_insights.html.erb

Tag-based analytics and insights

## \_site_insights.html.erb

Site-level performance insights

## \_calendar.html.erb

Calendar visualization of entry distribution

## \_version.html.erb

Version information display

# Other Views

## comments.html.erb

Facebook comments view with sentiment analysis

## history.html.erb

Report history view

# Chart Integration

Uses Chartkick with Highcharts adapter for:

- Column charts (temporal data)
- Pie/donut charts (distributions)
- Click handlers for date drill-down
- Sentiment breakdown charts

# Styling

- Primary color: Indigo (`bg-indigo-600`)
- Sentiment colors: Green (positive), Red (negative), Gray (neutral)
- Responsive design with Tailwind CSS
- Custom DataTables pagination styling

# Related

- [TopicController](controller.md) - Controller that renders these views
- [Aggregator Service](aggregator_service.md) - Provides data for the views
- [PDF Service](pdf_service.md) - Generates PDF reports

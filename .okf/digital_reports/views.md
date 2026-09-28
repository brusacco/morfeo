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
6. **Entity Analysis** - Named entities (GLiNER2) detected in the topic's notes. Rendered by `topic/_entity_analysis.html.erb` from `@entity_analysis` (aggregator `entity_analysis` payload), placed above the word-analysis sections. Mirrors the word/bigram analysis with a **Nube / Lista** toggle (Alpine `view`): _Nube_ shows size-normalized pills (`tag/_entity_pill.html.erb`, sized by mention count via `@entity_max_mentions`/`@entity_min_mentions`) using the SAME indigo palette as the word/bigram pills; each pill shows the entity name, a small colored bullet (dot, per-type color) + type label, and a dark indigo count badge (`bg-indigo-600 text-white`) with the mention count — matching the word/bigram count badge. _Lista_ shows a ranked list (rank + name + type badge, no mention bar). Both views share the search box (`filterEntities` filters `.entity-row` + `.entity-item`). Header shows type-breakdown chips (label + entity count, no mention total); footer shows "Entidades únicas" + "Tipo más frecuente" (no mention total)
7. **Word Cloud** - Visual word frequency with sentiment coloring
8. **Word/Bigram Lists** - Frequency tables
9. **Site Distribution** - Entries and interactions by news site
10. **DataTables** - Sortable/searchable table of all entries
11. **Top Entries Grid** - Visual cards of top performing entries
12. **Calendar View** - Calendar visualization of entry distribution

## pdf.html.erb

Print-optimized report layout for PDF generation:

- A4 page size with 2cm margins
- Page break controls
- Print-specific font sizes
- Chart sizing optimized for print
- Auto-print JavaScript trigger
- Comprehensive sections matching web view
- **Entities slide** (`ENT1`, "Análisis de Entidades") — rendered above the "Análisis de Palabras" slide when `@presenter.has_entity_data?`; two columns: top 8 entities by mentions (with type label + color) and distribution by entity type. Data comes from `DigitalPdfPresenter#entity_list` / `#entity_types` (backed by the PDF service `entity_analysis` payload); type labels via `pdf.entity_types.*` i18n keys

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

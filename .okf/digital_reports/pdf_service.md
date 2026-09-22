---
type: Service
title: Digital PDF Service
description: PDF generation service for digital media topic reports
resource: app/services/digital_dashboard_services/pdf_service.rb
tags: [digital, reports, service, pdf, entries]
timestamp: 2026-09-22T00:00:00Z
---

# Overview

The PdfService handles PDF generation for digital media topic reports using the Grover gem (Chrome headless). It provides optimized data loading specifically for PDF output.

# Interface

```ruby
DigitalDashboardServices::PdfService.call(
  topic: topic,
  days_range: 7
)
```

# Return Structure

Returns a hash with the same structure as AggregatorService, optimized for PDF output:

- `topic_data` - Core topic analytics data
- `chart_data` - Chart data for visualizations
- `tags_and_words` - Tag and word frequency data
- `percentages` - Percentage breakdowns

# Features

- A4 page size with 2cm margins
- Print-optimized layout
- Chart rendering with Highcharts
- Auto-print trigger
- Color preservation for print
- Optimized data loading for PDF (fewer records, faster generation)

# Dependencies

- Grover gem for HTML-to-PDF conversion
- Chrome/Chromium headless browser
- Chartkick with Highcharts adapter

# Related

- [TopicController](controller.md) - Invokes PDF generation
- [Digital Topic Views](views.md) - PDF template

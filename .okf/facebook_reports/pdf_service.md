---
type: Service
title: Facebook PDF Service
description: PDF generation service for Facebook topic reports
resource: app/services/facebook_dashboard_services/pdf_service.rb
tags: [facebook, reports, service, pdf]
timestamp: 2026-09-22T00:00:00Z
---

# Overview

The PdfService handles PDF generation for Facebook topic reports using the Grover gem (Chrome headless).

# Interface

```ruby
FacebookDashboardServices::PdfService.call(
  topic: topic,
  html: html_content,
  filename: "report.pdf"
)
```

# Features

- A4 page size with 2cm margins
- Print-optimized layout
- Chart rendering with Highcharts
- Auto-print trigger
- Color preservation for print

# Dependencies

- Grover gem for HTML-to-PDF conversion
- Chrome/Chromium headless browser
- Chartkick with Highcharts adapter

# Related

- [FacebookTopicController](controller.md) - Invokes PDF generation
- [Facebook Topic Views](views.md) - PDF template

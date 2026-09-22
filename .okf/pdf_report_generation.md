---
type: Architecture
title: PDF Report Generation
description: PDF report generation system using Grover and Chrome headless
tags: [pdf, reports, grover, generation]
timestamp: 2026-09-22T00:00:00Z
---

# Overview

Morfeo generates professional PDF reports for all analytics dashboards using the Grover gem with Chrome headless rendering. The system supports topic-specific reports for digital media, Facebook, Twitter, and Instagram, plus general CEO-level reports and tag-specific reports.

# PDF Generation Architecture

## Technology Stack

- **Grover gem**: HTML-to-PDF conversion using Chrome headless
- **Chartkick + Highcharts**: Chart rendering within PDFs
- **Tailwind CSS**: Styling for print-optimized layouts
- **Redis caching**: PDF data caching for performance

## Grover Configuration

Located in `config/initializers/grover.rb`:

```ruby
Grover.configure do |config|
  config.options = {
    format: 'A4',
    margin: { top: '2.5cm', bottom: '2.5cm', left: '2cm', right: '2cm' },
    prefer_css_page_size: true,
    emulate_media: 'screen',
    print_background: true,
    scale: 1.0,
    timeout: 60000,  # 60 seconds for complex reports
    wait_until: 'networkidle0',  # Wait for charts to load
    extra_http_headers: { 'Accept-Language': 'es-ES,es;q=0.9' }
  }
end
```

# PDF Report Types

## Topic PDF Reports

Digital, Facebook, and Twitter use dedicated PDF services. Instagram reuses its dashboard aggregator with a PDF-specific top-post limit.

### Digital Media PDF

- **Controller**: `TopicController#pdf`
- **Service**: `DigitalDashboardServices::PdfService`
- **Route**: `GET /topic/:id/pdf`
- **Content**: Entries, sentiment analysis, site distribution, word analysis

### Facebook PDF

- **Controller**: `FacebookTopicController#pdf`
- **Service**: `FacebookDashboardServices::PdfService`
- **Route**: `GET /facebook_topics/:id/pdf`
- **Content**: Posts, reaction breakdowns, sentiment analysis, page distribution

### Twitter PDF

- **Controller**: `TwitterTopicController#pdf`
- **Service**: `TwitterDashboardServices::PdfService`
- **Route**: `GET /twitter_topics/:id/pdf`
- **Content**: Tweets, engagement metrics, profile distribution, word analysis

### Instagram PDF

- **Controller**: `InstagramTopicController#pdf`
- **Service**: `InstagramDashboardServices::AggregatorService`
- **Route**: `GET /instagram_topics/:id/pdf`
- **Content**: Posts, engagement metrics, profile distribution, word analysis

## General Dashboard PDF

- **Controller**: `GeneralDashboardController#pdf`
- **Service**: `GeneralDashboardServices::AggregatorService`
- **Route**: `GET /general_dashboards/:id/pdf`
- **Content**: CEO-level executive summary combining all platforms

## Tag PDF Reports

- **Controller**: `TagController#pdf`
- **Service**: `TagPdfServices::PdfService`
- **Route**: `GET /tag/:id/pdf`
- **Content**: Tag-specific analytics across all platforms

# PDF Service Architecture

All PDF services follow the ApplicationService pattern:

```ruby
class PdfService < ApplicationService
  def initialize(topic:, days_range: DAYS_RANGE)
    @topic = topic
    @days_range = days_range
    @tag_names = @topic.tags.pluck(:name)
  end

  def call
    {
      topic_data: topic_data,
      chart_data: load_chart_data,
      tags_and_words: load_tags_and_words,
      percentages: calculate_pdf_percentages
    }
  end
end
```

## PDF Service Components

### Topic Data Loading

- Loads entries/posts for the topic and date range
- Calculates aggregations (counts, totals, polarity breakdowns)
- Computes site/profile distribution data

### Chart Data Generation

- Generates time-series data for posts/day and interactions/day
- Prepares data for Chartkick/Highcharts rendering

### Tags and Word Analysis

- Calculates word occurrences (minimum frequency: 5)
- Calculates bigram occurrences (minimum frequency: 2)
- Filters using Spanish stop words
- Minimum word length: 3 characters

### Percentage Calculations

- Computes share of voice percentages
- Calculates sentiment distribution percentages
- Determines platform share percentages

# PDF Caching

The `PdfCacheable` concern provides intelligent PDF caching:

```ruby
module PdfCacheable
  PDF_CACHE_DURATIONS = {
    digital: 30.minutes,
    facebook: 30.minutes,
    twitter: 30.minutes,
    general: 1.hour
  }

  def fetch_cached_pdf(type:, topic_id:, days_range:, **options, &block)
    cache_key = self.class.pdf_cache_key(type: type, topic_id: topic_id, days_range: days_range, **options)
    Rails.cache.fetch(cache_key, expires_in: cache_duration, &block)
  end
end
```

## Cache Key Structure

```
pdf/{type}/topic_{topic_id}/days_{days_range}/{date}
```

## Cache Management

- **Fetch**: `fetch_cached_pdf(type:, topic_id:, days_range:, &block)`
- **Expire**: `expire_pdf_cache(type:, topic_id:, days_range:)`
- **Check**: `pdf_cached?(type:, topic_id:, days_range:)`
- **Stats**: `pdf_cache_stats(type:, topic_id:, days_range:)`

# PDF View Templates

All PDF views use `layout: false` for print-optimized rendering:

```erb
<!-- app/views/topic/pdf.html.erb -->
<!DOCTYPE html>
<html lang="es">
<head>
  <meta charset="UTF-8">
  <title>Reporte - <%= @topic.name %></title>
  <%= stylesheet_link_tag 'pdf', media: 'all' %>
</head>
<body>
  <!-- PDF content with charts and data -->
</body>
</html>
```

# PDF Generation Flow

1. **Controller receives PDF request** with topic ID and days_range
2. **PDF Service called** to aggregate and format data
3. **Data cached** in Redis (30 minutes for topic PDFs, 1 hour for general)
4. **View rendered** with layout: false
5. **Grover converts HTML to PDF** using Chrome headless
6. **PDF returned** to user as downloadable file

# Performance Optimizations

- **Redis caching**: PDF data cached to avoid repeated expensive calculations
- **Limited top posts**: PDFs show top 10 posts (vs 12 in web view)
- **Chart optimization**: Charts sized for print (200px height)
- **Wait for resources**: Grover waits for networkidle0 to ensure charts load
- **60-second timeout**: Allows complex reports with many charts to complete

# Related

- [Caching Strategy](caching_strategy.md) - Overall caching architecture
- [Aggregator Services](aggregator_services.md) - Data aggregation services
- [Digital Reports](digital_reports/) - Digital media analytics
- [Facebook Reports](facebook_reports/) - Facebook analytics
- [Twitter Reports](twitter_reports/) - Twitter analytics
- [Instagram Reports](instagram_reports/) - Instagram analytics
- [Reporting](business_rules/reporting.md) - Report generation business rules

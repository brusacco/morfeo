---
type: concept
title: Presenters
description: Presenter layer for formatting data for views and PDF generation
tags:
  - architecture
  - presenters
  - views
  - formatting
timestamp: 2026-09-26T00:00:00Z
---

# Presenters

Morfeo uses presenters to format and prepare data for display in views and PDF generation. Presenters sit between controllers and views, handling presentation logic.

## Presenter Classes

### Digital PDF Presenter

**File:** `app/presenters/digital_pdf_presenter.rb`

Formats digital media data for PDF report generation.

### Facebook Sentiment Presenter

**File:** `app/presenters/facebook_sentiment_presenter.rb`

Formats Facebook sentiment data for display.

### General Dashboard Presenter

**File:** `app/presenters/general_dashboard_presenter.rb`

Formats four-channel dashboard data for display and PDF generation. Its channel
performance, reach breakdown, and comparison chart methods include digital,
Facebook, Twitter, and Instagram; Instagram uses the PDF brand color and the
localized channel label.

The General Dashboard PDF renders Instagram in its channel comparisons and
featured-content section when posts are present. The presenter links this
presentation contract to the [General Dashboard Aggregator](aggregator_services.md),
which owns the underlying cache and metric semantics.

### Sentiment Chart Presenter

**File:** `app/presenters/sentiment_chart_presenter.rb`

Formats sentiment data for chart visualization.

### Tag PDF Presenter

**File:** `app/presenters/tag_pdf_presenter.rb`

Formats tag-based data for PDF report generation.

### Twitter Dashboard Presenter

**File:** `app/presenters/twitter_dashboard_presenter.rb`

Formats Twitter dashboard data for display.

## Usage Pattern

```ruby
# In controller
@presenter = DigitalPdfPresenter.new(topic, data)

# In view
<%= @presenter.formatted_title %>
<%= @presenter.chart_data %>
```

## Responsibilities

- Format dates, numbers, and text for display
- Prepare data structures for charts and visualizations
- Handle localization and formatting rules
- Separate presentation logic from business logic

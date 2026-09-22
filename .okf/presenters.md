---
type: concept
title: Presenters
description: Presenter layer for formatting data for views and PDF generation
tags:
  - architecture
  - presenters
  - views
  - formatting
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

Formats cross-channel dashboard data for display.

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
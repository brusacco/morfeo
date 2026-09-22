---
type: concept
title: Controllers
description: Controller layer architecture, authorization concerns, caching strategy, and error handling patterns
tags:
  - architecture
  - web
  - rails
  - controllers
  - authorization
  - caching
---

# Controllers

Morfeo's controller layer follows Rails conventions with a clear separation of concerns. Controllers handle request processing, authorization, and view assignment, delegating business logic to service objects.

## Architecture Overview

```
ApplicationController (base)
├── TopicController (digital media)
├── FacebookTopicController
├── TwitterTopicController
├── InstagramTopicController
├── GeneralDashboardController (cross-channel)
├── TagController
├── EntryController
├── HomeController
├── SiteController
├── TemplatesController
├── API Controllers (api/v1/)
└── User Controllers (users/)
```

## Base Controller: ApplicationController

**File:** `app/controllers/application_controller.rb`

Provides shared functionality for all controllers:

- **CSRF Protection:** `protect_from_forgery with: :exception`
- **Paper Trail:** `before_action :set_paper_trail_whodunnit` for audit logging
- **User Topics:** `before_action :user_topics` loads active topics for the current user
- **Word Analysis:** `word_occurrences` and `bigram_occurrences` helper methods for text analysis

### User Topics Loading

```ruby
def user_topics
  relation = if user_signed_in?
    current_user.topics.where(status: true)
  else
    Topic.active
  end
  @topicos = relation
  @facebook_topics = relation
end
```

## Authorization Concerns

### TopicAuthorizable

**File:** `app/controllers/concerns/topic_authorizable.rb`

Provides consistent authorization for topic-based controllers.

**Usage Pattern:**

```ruby
class MyTopicController < ApplicationController
  include TopicAuthorizable
  before_action :set_topic
  before_action :authorize_topic_access!, only: [:show, :pdf]
end
```

**Authorization Checks:**

1. Topic exists (`topic_exists?`)
2. Topic is active (`topic_active?`)
3. User has access (`user_has_topic_access?`)

**Key Methods:**

- `authorize_topic_access!` - Main authorization method
- `can_access_topic?` - Override for custom logic
- `handle_unauthorized_topic_access` - Override for custom error handling

### TagAuthorizable

**File:** `app/controllers/concerns/tag_authorizable.rb`

Similar authorization pattern for tag-based controllers.

### PdfCacheable

**File:** `app/controllers/concerns/pdf_cacheable.rb`

Provides intelligent caching for PDF generation.

**Cache Durations:**

- Digital/Facebook/Twitter PDFs: `PdfConstants::PDF_CACHE_DURATION`
- General dashboard PDFs: 1 hour

**Key Methods:**

- `pdf_cache_key(type:, topic_id:, days_range:, **options)` - Generate cache key
- `fetch_cached_pdf(type:, topic_id:, days_range:, **options, &block)` - Get cached or generate new PDF

## Topic Controllers

All topic controllers follow a consistent pattern:

1. Authenticate user
2. Set topic (`set_topic` before_action)
3. Authorize access (`authorize_topic_access!`)
4. Use aggregator service to load data
5. Assign data to instance variables for views
6. Cache actions (30 minutes)

### TopicController (Digital Media)

**File:** `app/controllers/topic_controller.rb`

**Actions:**

- `show` - Digital media dashboard
- `pdf` - Generate PDF report
- `entries_data` - AJAX endpoint for chart entries
- `comments` - Topic comments
- `history` - Topic history

**Data Loading:**

```ruby
dashboard_data = DigitalDashboardServices::AggregatorService.call(
  topic: @topic,
  days_range: DAYS_RANGE
)
```

### FacebookTopicController

**File:** `app/controllers/facebook_topic_controller.rb`

**Constants:**

- `TOP_POSTS_SHOW_LIMIT = 20`
- `TOP_POSTS_PDF_LIMIT = 10`
- `TAG_LIMIT = 20`
- `SITE_LIMIT = 12`
- `CACHE_DURATION = 30.minutes`

**Actions:**

- `show` - Facebook dashboard
- `pdf` - Facebook PDF report
- `entries_data` - AJAX endpoint for Facebook posts

**Data Loading:**

```ruby
dashboard_data = FacebookDashboardServices::AggregatorService.call(
  topic: @topic,
  top_posts_limit: TOP_POSTS_SHOW_LIMIT,
  days_range: DAYS_RANGE
)
```

### TwitterTopicController

**File:** `app/controllers/twitter_topic_controller.rb`

Same pattern as FacebookTopicController, using `TwitterDashboardServices::AggregatorService`.

### InstagramTopicController

**File:** `app/controllers/instagram_topic_controller.rb`

Same pattern as FacebookTopicController, using `InstagramDashboardServices::AggregatorService`.

## GeneralDashboardController

**File:** `app/controllers/general_dashboard_controller.rb`

Cross-channel CEO-level reporting and analytics.

**Includes:** `TopicAuthorizable`, `PdfCacheable`

**Actions:**

- `show` - General dashboard with executive summary
- `pdf` - General PDF report with caching

**Data Loading:**

```ruby
@dashboard_data = GeneralDashboardServices::AggregatorService.call(
  topic: @topic,
  start_date: @start_date,
  end_date: @end_date
)
```

**Dashboard Sections:**

- Executive Summary
- Channel Performance
- Temporal Intelligence
- Sentiment Analysis
- Reach Analysis
- Competitive Analysis
- Top Content
- Word Analysis
- Recommendations

## TagController

**File:** `app/controllers/tag_controller.rb`

**Includes:** `TagAuthorizable`

**Actions:**

- `show` - Tag dashboard
- `entries_data` - AJAX endpoint for tag entries
- `comments` - Tag comments
- `report` - Tag report
- `pdf` - Tag PDF report

## EntryController

**File:** `app/controllers/entry_controller.rb`

**Constants:**

- `POPULAR_ENTRIES_LIMIT = 50`
- `COMMENTED_ENTRIES_LIMIT = 50`
- `TAG_LIMIT = 20`
- `SEARCH_LIMIT = 50`
- `CACHE_DURATION = 30.minutes`

**Actions:**

- `show` - Entry detail
- `popular` - Popular Facebook entries (cached)
- `commented` - Most commented entries (cached)
- `week` - Weekly entries (cached)

## HomeController

**File:** `app/controllers/home_controller.rb`

**Actions:**

- `index` - Executive dashboard with cross-topic analytics
- `deploy` - Deployment webhook (no auth)
- `check` - Health check webhook (no auth)

**Data Loading:**

```ruby
dashboard_data = HomeServices::DashboardAggregatorService.call(
  topics: @topicos,
  days_range: DAYS_RANGE
)
```

**Dashboard Sections:**

- Executive Summary
- Channel Stats
- Topic Statistics & Trends
- Alerts
- Top Content
- Sentiment Intelligence
- Temporal Intelligence
- Competitive Intelligence

## SiteController

**File:** `app/controllers/site_controller.rb`

**Actions:**

- `show` - Site dashboard

**Data Loading:**

```ruby
data = SiteDashboardServices::AggregatorService.call(site: @site)
```

## TemplatesController

**File:** `app/controllers/templates_controller.rb`

**Authentication:** `authenticate_admin_user!`

**Actions:**

- `show` - Template report with date filtering

**Date Filtering Logic:**

- No dates: Last 7 days to today
- Only start date: Start date to today
- Both dates: Custom range

## API Controllers

**Location:** `app/controllers/api/v1/`

- `entries_controller.rb`
- `sites_controller.rb`
- `tags_controller.rb`
- `topics_controller.rb`

Provide REST API endpoints for external integrations.

## User Controllers

**Location:** `app/controllers/users/`

Devise-based authentication controllers:

- `confirmations_controller.rb`
- `omniauth_callbacks_controller.rb`
- `passwords_controller.rb`
- `registrations_controller.rb`
- `sessions_controller.rb`
- `unlocks_controller.rb`

## Caching Strategy

All topic controllers use action caching with 30-minute expiration:

```ruby
caches_action :show, :pdf, expires_in: 30.minutes,
  cache_path: proc { |c| { topic_id: c.params[:id], user_id: c.current_user.id, days_range: c.params[:days_range] } }
```

Cache keys include:

- Topic ID
- User ID (per-user caching)
- Days range (different time periods)

## Error Handling Pattern

Controllers use consistent error handling with partial rendering:

```ruby
rescue ActiveRecord::RecordNotFound => e
  Rails.logger.error "Error: #{e.message}"
  render partial: 'shared/error_message',
    locals: { message: 'Tópico no encontrado' },
    status: :not_found
rescue StandardError => e
  Rails.logger.error "Error: #{e.class} - #{e.message}"
  Rails.logger.error e.backtrace.first(5).join("\n")
  render partial: 'shared/error_message',
    locals: { message: 'Error cargando datos' },
    status: :internal_server_error
end
```

## Related Concepts

- [Aggregator Services](aggregator_services.md) - Data loading services used by controllers
- [Caching Strategy](caching_strategy.md) - Multi-layer caching architecture
- [PDF Report Generation](pdf_report_generation.md) - PDF generation system
- [Business Rules](business_rules/) - Authorization and access rules

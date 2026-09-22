---
type: concept
title: Services
description: Service object architecture for business logic, data aggregation, crawling, and external API integration
tags:
  - architecture
  - services
  - business-logic
  - service-object
  - aggregation
---

# Services

Morfeo uses the service object pattern extensively. All services inherit from `ApplicationService` and follow the `.call(...)` convention with result objects.

## Architecture

```
ApplicationService (base)
├── Dashboard Aggregator Services
│   ├── DigitalDashboardServices::AggregatorService
│   ├── FacebookDashboardServices::AggregatorService
│   ├── TwitterDashboardServices::AggregatorService
│   ├── InstagramDashboardServices::AggregatorService
│   ├── GeneralDashboardServices::AggregatorService
│   ├── HomeServices::DashboardAggregatorService
│   └── SiteDashboardServices::AggregatorService
├── PDF Services
│   ├── DigitalDashboardServices::PdfService
│   ├── FacebookDashboardServices::PdfService
│   ├── TwitterDashboardServices::PdfService
│   └── TagPdfServices::PdfService
├── Web Extractor Services
│   ├── ExtractBasicInfo
│   ├── ExtractContent
│   ├── ExtractDate
│   ├── ExtractTags
│   ├── ExtractBigrams
│   ├── ExtractTitleTags
│   ├── ExtractFacebookEntryTags
│   └── UrlCrawler
├── Crawler Services
│   ├── Headless Crawler (Selenium)
│   │   ├── Orchestrator
│   │   ├── SiteCrawler
│   │   ├── LinkExtractor
│   │   ├── EntryProcessor
│   │   └── BrowserManager
│   └── Proxy Crawler (scrape.do)
│       ├── Orchestrator
│       ├── SiteCrawler
│       ├── LinkExtractor
│       ├── EntryProcessor
│       └── ProxyClient
├── Facebook Services
│   ├── FanpageCrawler
│   ├── CommentCrawler
│   ├── UpdateStats
│   ├── UpdatePage
│   └── LinkToEntries
├── Twitter Services
│   ├── AccountManager
│   ├── GetPostsData
│   ├── GetPostsDataAuth
│   ├── GetProfileData
│   ├── UpdateProfile
│   ├── ProcessPosts
│   ├── ExtractTags
│   └── LinkToEntries
├── Instagram Services
│   ├── GetPostsData
│   ├── GetProfileData
│   ├── UpdateProfile
│   ├── ProcessPosts
│   └── ExtractTags
├── AI Services
│   └── OpenAiQuery
├── App Services
│   └── UpdateTagEntries
└── Application Service (base)
```

## Base Service: ApplicationService

**File:** `app/services/application_service.rb`

```ruby
class ApplicationService
  def self.call(...)
    new(...).call
  end

  def handle_error(error)
    OpenStruct.new({ success?: false, error: error })
  end

  def handle_success(data)
    if data.is_a?(Hash)
      OpenStruct.new({ success?: true, data: data, **data })
    else
      OpenStruct.new({ success?: true, data: data })
    end
  end
end
```

**Result Object Pattern:**

- `result.success?` - Boolean indicating success
- `result.data` - Result data (Hash or value)
- `result.error` - Error message (on failure)
- Hash data is splatted onto the result object for direct access

## Dashboard Aggregator Services

All dashboard aggregators follow the same pattern: accept topic and date range, return comprehensive dashboard data structure.

### DigitalDashboardServices::AggregatorService

**File:** `app/services/digital_dashboard_services/aggregator_service.rb`

Aggregates digital media (web article) analytics for a topic.

**Parameters:**

- `topic` - Topic object
- `days_range` - Number of days to analyze

**Returns:** Hash with topic data, chart data, percentages, and analytics.

### FacebookDashboardServices::AggregatorService

**File:** `app/services/facebook_dashboard_services/aggregator_service.rb`

Aggregates Facebook analytics for a topic.

**Parameters:**

- `topic` - Topic object
- `top_posts_limit` - Number of top posts to include
- `days_range` - Number of days to analyze

### TwitterDashboardServices::AggregatorService

**File:** `app/services/twitter_dashboard_services/aggregator_service.rb`

Aggregates Twitter analytics for a topic.

**Parameters:**

- `topic` - Topic object
- `top_posts_limit` - Number of top posts to include
- `days_range` - Number of days to analyze

### InstagramDashboardServices::AggregatorService

**File:** `app/services/instagram_dashboard_services/aggregator_service.rb`

Aggregates Instagram analytics for a topic.

**Parameters:**

- `topic` - Topic object
- `top_posts_limit` - Number of top posts to include
- `days_range` - Number of days to analyze

### GeneralDashboardServices::AggregatorService

**File:** `app/services/general_dashboard_services/aggregator_service.rb`

Cross-channel CEO-level analytics aggregating all data sources.

**Parameters:**

- `topic` - Topic object
- `start_date` - Start date
- `end_date` - End date

**Returns:** Comprehensive dashboard data including:

- Executive Summary
- Channel Performance
- Temporal Intelligence
- Sentiment Analysis
- Reach Analysis
- Competitive Analysis
- Top Content
- Word Analysis
- Recommendations

### HomeServices::DashboardAggregatorService

**File:** `app/services/home_services/dashboard_aggregator_service.rb`

Aggregates cross-topic analytics for the home dashboard.

**Parameters:**

- `topics` - Array of topics
- `days_range` - Number of days to analyze

### SiteDashboardServices::AggregatorService

**File:** `app/services/site_dashboard_services/aggregator_service.rb`

Aggregates analytics for a specific site.

**Parameters:**

- `site` - Site object

## PDF Services

### DigitalDashboardServices::PdfService

**File:** `app/services/digital_dashboard_services/pdf_service.rb`

Generates PDF reports for digital media dashboards.

### FacebookDashboardServices::PdfService

**File:** `app/services/facebook_dashboard_services/pdf_service.rb`

Generates PDF reports for Facebook dashboards.

### TwitterDashboardServices::PdfService

**File:** `app/services/twitter_dashboard_services/pdf_service.rb`

Generates PDF reports for Twitter dashboards.

### TagPdfServices::PdfService

**File:** `app/services/tag_pdf_services/pdf_service.rb`

Generates PDF reports for tag dashboards.

## Web Extractor Services

Services for extracting data from web pages.

### ExtractBasicInfo

**File:** `app/services/web_extractor_services/extract_basic_info.rb`

Extracts basic information (title, description, etc.) from a page.

### ExtractContent

**File:** `app/services/web_extractor_services/extract_content.rb`

Extracts main content from a page.

### ExtractDate

**File:** `app/services/web_extractor_services/extract_date.rb`

Extracts publication date from a page.

### ExtractTags

**File:** `app/services/web_extractor_services/extract_tags.rb`

Extracts tags/keywords from page content.

### ExtractBigrams

**File:** `app/services/web_extractor_services/extract_bigrams.rb`

Extracts bigrams (two-word phrases) from content.

### ExtractTitleTags

**File:** `app/services/web_extractor_services/extract_title_tags.rb`

Extracts tags from page titles.

### ExtractFacebookEntryTags

**File:** `app/services/web_extractor_services/extract_facebook_entry_tags.rb`

Extracts tags specific to Facebook entries.

### UrlCrawler

**File:** `app/services/web_extractor_services/url_crawler.rb`

Crawls URLs and extracts content.

## Crawler Services

### Headless Crawler (Selenium)

Uses Selenium WebDriver for JavaScript-heavy sites.

**Components:**

- `Orchestrator` - Coordinates crawling process
- `SiteCrawler` - Crawls individual sites
- `LinkExtractor` - Extracts links from pages
- `EntryProcessor` - Processes extracted entries
- `BrowserManager` - Manages browser instances

### Proxy Crawler (scrape.do)

Uses scrape.do proxy service for JavaScript rendering.

**Components:**

- `Orchestrator` - Coordinates crawling process
- `SiteCrawler` - Crawls individual sites
- `LinkExtractor` - Extracts links from pages
- `EntryProcessor` - Processes extracted entries
- `ProxyClient` - Manages scrape.do API communication

## Facebook Services

### FanpageCrawler

**File:** `app/services/facebook_services/fanpage_crawler.rb`

Crawls Facebook fanpages for posts.

### CommentCrawler

**File:** `app/services/facebook_services/comment_crawler.rb`

Crawls comments on Facebook posts.

### UpdateStats

**File:** `app/services/facebook_services/update_stats.rb`

Updates engagement statistics for Facebook entries.

### UpdatePage

**File:** `app/services/facebook_services/update_page.rb`

Updates Facebook page information.

### LinkToEntries

**File:** `app/services/facebook_services/link_to_entries.rb`

Links Facebook posts to entries.

## Twitter Services

### AccountManager

**File:** `app/services/twitter_services/account_manager.rb`

Manages multiple Twitter API accounts with rate limit rotation.

### GetPostsData

**File:** `app/services/twitter_services/get_posts_data.rb`

Fetches Twitter posts using guest token (unauthenticated).

### GetPostsDataAuth

**File:** `app/services/twitter_services/get_posts_data_auth.rb`

Fetches Twitter posts using authenticated API.

### GetProfileData

**File:** `app/services/twitter_services/get_profile_data.rb`

Fetches Twitter profile data.

### UpdateProfile

**File:** `app/services/twitter_services/update_profile.rb`

Updates Twitter profile information.

### ProcessPosts

**File:** `app/services/twitter_services/process_posts.rb`

Processes and stores Twitter posts.

### ExtractTags

**File:** `app/services/twitter_services/extract_tags.rb`

Extracts tags from Twitter posts.

### LinkToEntries

**File:** `app/services/twitter_services/link_to_entries.rb`

Links Twitter posts to entries.

## Instagram Services

### GetPostsData

**File:** `app/services/instagram_services/get_posts_data.rb`

Fetches Instagram posts via API.

### GetProfileData

**File:** `app/services/instagram_services/get_profile_data.rb`

Fetches Instagram profile data.

### UpdateProfile

**File:** `app/services/instagram_services/update_profile.rb`

Updates Instagram profile information.

### ProcessPosts

**File:** `app/services/instagram_services/process_posts.rb`

Processes and stores Instagram posts.

### ExtractTags

**File:** `app/services/instagram_services/extract_tags.rb`

Extracts tags from Instagram posts.

## AI Services

### OpenAiQuery

**File:** `app/services/ai_services/open_ai_query.rb`

Interfaces with OpenAI API for AI-powered features (sentiment analysis, etc.).

## App Services

### UpdateTagEntries

**File:** `app/services/app_services/update_tag_entries.rb`

Updates tag associations for entries.

## Related Concepts

- [Controllers](controllers.md) - Controllers that use these services
- [Jobs](jobs.md) - Background jobs that call services
- [Aggregator Services](aggregator_services.md) - Detailed aggregator documentation
- [PDF Report Generation](pdf_report_generation.md) - PDF generation system
- [Crawler Infrastructure](crawler_infrastructure.md) - Crawler architecture
- [Twitter Account Management](twitter_account_management.md) - Multi-account Twitter API

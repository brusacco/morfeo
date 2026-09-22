---
type: Architecture
title: Crawler Infrastructure
description: Complete documentation of all crawler types and their architectures
tags: [crawler, scraping, web, automation, data-collection]
timestamp: 2026-09-22T00:00:00Z
---

# Overview

Morfeo uses a multi-tier crawler infrastructure to collect content from various sources. The system includes standard web crawling, JavaScript-rendered site crawling (headless), proxy-based crawling, and social media URL crawling. Each crawler type is optimized for specific use cases and site characteristics.

# Crawler Types

## 1. Standard Web Crawler

**Location**: `lib/tasks/crawler.rake`
**Technology**: Anemone web crawler library
**Use Case**: Standard HTML websites without JavaScript rendering

### Configuration

- **Depth**: Configurable (default: 2, deep crawl: 3, range: 1-5)
- **Sites**: `Site.enabled.where(is_js: false)` - Non-JavaScript sites only
- **Ordering**: Sites processed by `total_count` descending (most active first)

### Key Features

- **Binary File Exclusion**: Filters out images, PDFs, audio, video files
- **Directory Exclusion**: Skips common non-content directories (wp-admin, wp-login, tag, category, etc.)
- **Site-Specific Filters**: Uses per-site inclusion (`filter`) and exclusion (`negative_filter`) regex patterns
- **Connection Pool Optimization**: Loads sites into array first to release database connections
- **Pre-compiled Regexes**: Compiles filter patterns once per site for performance

### Constants

```ruby
BINARY_FILE_EXTENSIONS = /.*\.(jpeg|jpg|gif|png|pdf|mp3|mp4|mpeg)/
EXCLUDED_DIRECTORIES = %w[blackhole wp-login wp-admin galerias fotoblog radios page etiqueta categoria category pagina auth wp-content img tag contacto programa date feed]
DEFAULT_NEGATIVE_FILTER = 'NUNCA'  # Regex that never matches
```

### Usage

```bash
rake crawler              # Standard crawl (depth: 2)
rake crawler[3]           # Deep crawl (depth: 3)
```

## 2. Headless Crawler (Selenium)

**Location**: `lib/tasks/headless_crawler.rake`
**Services**: `app/services/headless_crawler_services/`
**Technology**: Selenium WebDriver with Chrome headless
**Use Case**: JavaScript-rendered websites that require browser execution

### Architecture

The headless crawler uses a service-oriented architecture with four main components:

#### Orchestrator (`orchestrator.rb`)

- Manages browser lifecycle and coordinates site crawling
- Handles site selection and processing order
- Tracks overall statistics

#### Browser Manager (`browser_manager.rb`)

- Manages Selenium WebDriver lifecycle and configuration
- Configures Chrome with headless mode, proxy support, and anti-detection options
- Handles browser initialization and cleanup

#### Site Crawler (`site_crawler.rb`)

- Crawls individual sites using the browser driver
- Extracts links and processes content
- Handles site-specific navigation

#### Entry Processor (`entry_processor.rb`)

- Processes extracted content into Entry records
- Handles deduplication and validation

#### Link Extractor (`link_extractor.rb`)

- Extracts URLs from page content
- Applies filter patterns

### Key Features

- **Chrome Headless Mode**: Uses `--headless=new` for less detectable crawling
- **Proxy Support**: Optional scrape.do proxy integration for IP rotation
- **Anti-Detection**: User agent rotation and browser fingerprinting options
- **Timeout Handling**: Configurable timeouts for page loads and requests
- **Error Recovery**: Automatic retry and error handling per site

### Usage

```bash
rake crawler:headless                    # Crawl all JS-enabled sites
rake crawler:headless:site[1,2,3]        # Crawl specific sites by ID
rake crawler:headless:site_proxy[1,2,3]  # Crawl specific sites with proxy
```

## 3. Proxy Crawler (scrape.do)

**Location**: `lib/tasks/proxy_crawler.rake`
**Services**: `app/services/proxy_crawler_services/`
**Technology**: scrape.do API with headless browser rendering
**Use Case**: JavaScript sites requiring proxy-based rendering and IP rotation

### Architecture

Similar to the headless crawler but uses the scrape.do API instead of local Selenium:

#### Orchestrator (`orchestrator.rb`)

- Coordinates proxy-based crawling across sites
- Manages proxy client lifecycle

#### Proxy Client (`proxy_client.rb`)

- Interfaces with scrape.do API
- Handles authentication and request formatting
- Manages API rate limits and errors

#### Site Crawler (`site_crawler.rb`)

- Crawls individual sites via proxy
- Processes proxy responses

#### Entry Processor (`entry_processor.rb`)

- Processes content from proxy responses into Entry records

#### Link Extractor (`link_extractor.rb`)

- Extracts URLs from proxy-fetched content

### Key Features

- **scrape.do Integration**: Uses professional scraping API
- **Headless Browser Rendering**: `render=true` parameter for JavaScript execution
- **IP Rotation**: Automatic IP rotation via scrape.do infrastructure
- **Anti-Bot Protection**: Built-in anti-bot detection bypass
- **Timeout Configuration**: Configurable timeouts for API requests

### Configuration

```ruby
# scrape.do API parameters
{
  render: 'true',                    # Use headless browser (Chromium)
  wait: '5',                         # Wait time for page load
  timeout: '30',                     # Request timeout
  'api-key': ENV['SCRAPE_DO_TOKEN']
}
```

### Usage

```bash
rake crawler:proxy                     # Crawl all JS-enabled sites via proxy
rake crawler:proxy:site[1,2,3]         # Crawl specific sites via proxy
```

## 4. Social Media Crawler

**Location**: `lib/tasks/social_crawler.rake`
**Technology**: Nokogiri, Open-URI, Parallel processing
**Use Case**: Crawling URLs from unlinked social media posts (Twitter and Facebook)

### Key Features

- **Parallel Processing**: Uses 5 threads for concurrent processing
- **URL Extraction**: Extracts URLs from Twitter and Facebook post payloads
- **URL Normalization**: Standardizes URLs for matching
- **Site Matching**: Finds associated sites for crawled URLs
- **Entry Creation**: Creates new Entry records for discovered URLs
- **Linking**: Links social posts to discovered/created entries

### Processing Flow

1. Find unlinked Twitter/Facebook posts
2. Extract URLs from post payloads
3. Normalize URLs
4. Find associated sites
5. Check for existing entries
6. Fetch and process new URLs
7. Link social posts to entries

### Ignored Sites

```ruby
IGNORED_SITE_IDS = [142].freeze
```

### Usage

```bash
rake social_crawler
```

## 5. Facebook Fanpage Crawler

**Location**: `app/services/facebook_services/fanpage_crawler.rb`
**Technology**: Facebook Graph API v18.0
**Use Case**: Crawling Facebook posts from tracked Pages

### Key Features

- **Graph API Integration**: Uses Facebook Graph API for post retrieval
- **Full Reaction Breakdown**: Captures all reaction types (like, love, wow, haha, sad, angry, thankful)
- **Engagement Metrics**: Collects comments, shares, and estimated views
- **Pagination**: Handles API pagination for complete post retrieval
- **Error Handling**: Handles API errors and rate limits

### Usage

```bash
rake facebook:fanpage_crawler[1]  # Crawl Facebook pages (3 pages = ~300 posts per page)
```

## 6. Twitter Profile Crawler

**Location**: `app/services/twitter_services/`
**Technology**: Twitter GraphQL API (Guest Token and Authenticated)
**Use Case**: Crawling tweets from tracked Twitter profiles

### Key Features

- **Dual API Support**: Guest Token API (cached) and Authenticated API (real-time)
- **Account Rotation**: Automatic rotation between multiple Twitter accounts
- **Pagination**: Fetches up to 500 tweets with pagination
- **Engagement Metrics**: Collects favorites, retweets, replies, quotes, views, bookmarks
- **Rate Limit Handling**: Automatic rate limit detection and rotation

### Usage

```bash
rake twitter:profile_crawler       # Incremental crawl (stops on duplicates)
rake twitter:profile_crawler_full  # Full crawl (updates existing metrics)
```

## 7. Instagram Posts Crawler

**Location**: `app/services/instagram_services/`
**Technology**: Instagram Graph API
**Use Case**: Crawling Instagram posts from tracked profiles

### Key Features

- **Graph API Integration**: Uses Instagram Graph API for post retrieval
- **Media Download**: Automatically downloads post images
- **Engagement Metrics**: Collects likes and comments
- **Business Account Support**: Requires Instagram Business accounts

### Usage

```bash
rake instagram:posts_crawler
```

# Crawler Selection Logic

The system automatically selects the appropriate crawler based on site configuration:

```ruby
# Standard crawler: Non-JavaScript sites
Site.enabled.where(is_js: false)

# Headless/Proxy crawler: JavaScript sites
Site.enabled.where(is_js: true)
```

# Performance Optimizations

## Connection Pool Management

- Load sites into arrays before processing to release database connections
- Use `ActiveRecord::Base.connection_pool.with_connection` for parallel processing

## Regex Optimization

- Pre-compile filter patterns once per site
- Use `Regexp.new` with error handling for safe pattern compilation

## Parallel Processing

- Social media crawler uses 5 threads for concurrent processing
- Entry processing can be parallelized across sites

## Caching

- Crawler results cached in Redis for 30 minutes
- Dashboard data pre-warmed every 5 minutes

# Related

- [Content Crawling](business_rules/content_crawling.md) - Crawling business rules
- [Site Model](models/site.md) - Site configuration
- [Entry Model](models/entry.md) - Entry data structure
- [Scheduled Tasks](scheduled_tasks.md) - Crawler scheduling
- [Twitter Account Management](twitter_account_management.md) - Twitter API authentication

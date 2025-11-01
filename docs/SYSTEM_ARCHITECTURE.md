# Morfeo System Architecture & Implementation Documentation
**Last Updated**: November 1, 2025  
**Version**: 1.0  
**System**: Production Media Monitoring Platform

---

## 📋 Table of Contents

1. [System Architecture](#system-architecture)
2. [Background Jobs & Scheduling](#background-jobs--scheduling)
3. [API Integration](#api-integration)
4. [Service Layer](#service-layer)
5. [Web Scraping Pipeline](#web-scraping-pipeline)
6. [Data Processing Flow](#data-processing-flow)
7. [Caching Strategy](#caching-strategy)
8. [Security & Authentication](#security--authentication)
9. [Monitoring & Analytics](#monitoring--analytics)
10. [Deployment & Infrastructure](#deployment--infrastructure)

---

## 🏗️ System Architecture

### **High-Level Overview**

```
┌─────────────────────────────────────────────────────────────────┐
│                    MORFEO ARCHITECTURE                           │
└─────────────────────────────────────────────────────────────────┘

┌───────────────┐         ┌───────────────┐         ┌──────────────┐
│  Web Sources  │         │   Meta API    │         │ Twitter API  │
│ (News Sites)  │         │  (Facebook)   │         │   (X/API)    │
└───────┬───────┘         └───────┬───────┘         └──────┬───────┘
        │                         │                         │
        │ Anemone Crawler         │ Graph API              │ API v2
        │ (Nokogiri)              │ (HTTParty)             │ (Twitter gem)
        ▼                         ▼                         ▼
┌────────────────────────────────────────────────────────────────┐
│                    INGESTION LAYER                              │
│  ┌──────────┐    ┌─────────────┐    ┌──────────────┐          │
│  │ Crawler  │    │  Facebook   │    │   Twitter    │          │
│  │  Rake    │    │   Service   │    │   Service    │          │
│  │  Tasks   │    │  (Fanpage)  │    │  (Profile)   │          │
│  └─────┬────┘    └──────┬──────┘    └──────┬───────┘          │
└────────┼─────────────────┼───────────────────┼─────────────────┘
         │                 │                   │
         │                 │                   │
         ▼                 ▼                   ▼
┌────────────────────────────────────────────────────────────────┐
│                   PROCESSING LAYER                              │
│  ┌───────────┐  ┌──────────┐  ┌──────────┐  ┌─────────────┐  │
│  │ Extract   │  │  Tagger  │  │Sentiment │  │  Stats      │  │
│  │ Services  │  │ (acts_as │  │ Analysis │  │ Aggregator  │  │
│  │           │  │taggable) │  │ (OpenAI) │  │             │  │
│  └─────┬─────┘  └────┬─────┘  └────┬─────┘  └─────┬───────┘  │
└────────┼─────────────┼──────────────┼──────────────┼──────────┘
         │             │              │              │
         │             │              │              │
         ▼             ▼              ▼              ▼
┌────────────────────────────────────────────────────────────────┐
│                       DATA LAYER                                │
│  ┌──────────┐  ┌──────────┐  ┌──────────┐  ┌──────────────┐  │
│  │  MySQL   │  │  Redis   │  │Elastic-  │  │  Rails       │  │
│  │  8.0     │  │  Cache   │  │ search   │  │  Cache       │  │
│  │          │  │          │  │(Searchkick)   │             │  │
│  └─────┬────┘  └────┬─────┘  └────┬─────┘  └──────┬───────┘  │
└────────┼────────────┼─────────────┼─────────────────┼──────────┘
         │            │             │                 │
         │            │             │                 │
         ▼            ▼             ▼                 ▼
┌────────────────────────────────────────────────────────────────┐
│                   PRESENTATION LAYER                            │
│  ┌────────────┐  ┌─────────────┐  ┌──────────────┐           │
│  │ Dashboard  │  │   REST API  │  │  PDF Export  │           │
│  │ (Tailwind/ │  │ (JSON/RABL) │  │  (Grover)    │           │
│  │ Alpine.js) │  │             │  │              │           │
│  └────────────┘  └─────────────┘  └──────────────┘           │
└────────────────────────────────────────────────────────────────┘
```

---

## ⏰ Background Jobs & Scheduling

### **Cron Schedule (Whenever Gem)**

#### **Every Hour** (Hourly tasks - Core data collection)
```ruby
# config/schedule.rb
every :hour do
  rake 'crawler'              # Web scraping (digital media)
  rake 'proxy_crawler'        # Proxy-based scraping
  rake 'update_stats'         # Update entry statistics
  rake 'update_site_stats'    # Aggregate site-level stats
  rake 'update_dates'         # Fix missing publication dates
  rake 'clean_site_content'   # Clean up malformed content
  rake 'category'             # Auto-categorize entries
  rake 'topic_stat_daily'     # Daily topic aggregations
  rake 'title_topic_stat_daily' # Title-based daily stats
end
```

**Purpose**: Real-time data collection and basic processing  
**Frequency**: ~9 tasks per hour  
**Duration**: 20-45 minutes total  
**Critical**: ✅ Must run reliably for up-to-date news

---

#### **Every 3 Hours** (Social media crawling)
```ruby
every 3.hours do
  rake 'facebook:fanpage_crawler'     # Fetch Facebook posts
  rake 'twitter:profile_crawler_full' # Fetch tweets + update metrics
end
```

**Purpose**: Social media data ingestion  
**Frequency**: 8 times per day  
**Duration**: 15-30 minutes per run  
**Critical**: ✅ API rate limits require spacing  
**Special**:
- **Facebook**: Fetches 2 pages per fanpage (configurable in task)
- **Twitter**: Full crawl + updates engagement metrics for existing tweets

---

#### **Every 4 Hours** (Data enrichment)
```ruby
every 4.hours do
  rake 'repeated_notes'  # Detect duplicate articles
  rake 'title_tagger'    # Tag entries based on title keywords
end
```

**Purpose**: Content deduplication and tagging  
**Frequency**: 6 times per day  
**Duration**: 10-20 minutes  
**Note**: Helps maintain data quality

---

#### **Every 6 Hours** (Heavy processing)
```ruby
every 6.hours do
  rake 'crawler_deep'             # Deep web scraping (depth_limit: 3)
  rake 'ai:generate_ai_reports'   # OpenAI-generated summaries
  rake 'ai:set_topic_polarity'    # AI sentiment analysis
  rake 'facebook:update_fanpages' # Update page metadata
end
```

**Purpose**: AI processing and deep crawling  
**Frequency**: 4 times per day  
**Duration**: 30-60 minutes  
**Cost**: 💰 OpenAI API calls (GPT-3.5-turbo)  
**Critical**: ⚠️ Can be skipped if budget constrained

---

#### **Every 12 Hours** (Commented out - Optional)
```ruby
# Currently disabled
# every 12.hours do
#   rake 'twitter:link_to_entries'   # Link tweets to articles
#   rake 'facebook:link_to_entries'  # Link FB posts to articles
#   rake 'twitter:post_tagger'       # Tag tweets
#   rake 'facebook:entry_tagger'     # Tag FB posts
# end
```

**Status**: ❌ Disabled in production  
**Reason**: Linking happens automatically during crawling  
**Use Case**: Re-enable for historical data cleanup

---

### **Rake Task Catalog**

| Category | Task | Frequency | Purpose | Duration |
|----------|------|-----------|---------|----------|
| **Web Scraping** | `crawler` | Hourly | Crawl news sites | 15-30 min |
| | `crawler_deep` | 6h | Deep crawl (depth 3) | 30-45 min |
| | `proxy_crawler` | Hourly | Proxy-based crawling | 10-15 min |
| | `headless_crawler` | Manual | JavaScript rendering | 20-30 min |
| **Social Media** | `facebook:fanpage_crawler` | 3h | Fetch FB posts | 10-20 min |
| | `twitter:profile_crawler_full` | 3h | Fetch tweets + metrics | 10-20 min |
| | `facebook:update_fanpages` | 6h | Update page metadata | 5-10 min |
| **Data Quality** | `repeated_notes` | 4h | Detect duplicates | 5-10 min |
| | `clean_site_content` | Hourly | Clean malformed HTML | 5 min |
| | `update_dates` | Hourly | Fix missing dates | 5 min |
| **AI Processing** | `ai:generate_ai_reports` | 6h | OpenAI summaries | 20-30 min |
| | `ai:set_topic_polarity` | 6h | Sentiment analysis | 15-20 min |
| **Tagging** | `title_tagger` | 4h | Tag by title | 5-10 min |
| | `tagger` | Manual | Full content tagging | 30 min |
| **Statistics** | `topic_stat_daily` | Hourly | Daily topic stats | 5 min |
| | `title_topic_stat_daily` | Hourly | Title-based stats | 5 min |
| | `update_stats` | Hourly | Update entry stats | 10 min |
| | `update_site_stats` | Hourly | Aggregate site stats | 5 min |
| **Maintenance** | `category` | Hourly | Auto-categorize | 5 min |
| | `reindex_topic` | Manual | Elasticsearch reindex | 10-30 min |

---

## 🔌 API Integration

### **Meta API (Facebook Graph API)**

**Endpoint**: `https://graph.facebook.com/v18.0`  
**Authentication**: App-scoped access token  
**Rate Limits**: 200 calls per hour per app  

#### **Key Endpoints Used**:

```ruby
# 1. Fetch Page Posts
GET /{page_id}/posts
  ?fields=id,message,created_time,permalink_url,attachments,
          reactions.summary(total_count).limit(0),
          comments.summary(total_count).limit(0),
          shares
  &limit=25
  &access_token={token}
```

```ruby
# 2. Fetch Page Info
GET /{page_id}
  ?fields=id,name,username,picture,followers_count,category,description,website
  &access_token={token}
```

```ruby
# 3. Fetch Post Reactions (Detailed)
GET /{post_id}/reactions
  ?type=LIKE,LOVE,WOW,HAHA,SAD,ANGRY,THANKFUL
  &summary=total_count
  &access_token={token}
```

#### **Implementation**: `app/services/facebook_services/`

---

### **Twitter API v2**

**Endpoint**: `https://api.twitter.com/2`  
**Authentication**: Bearer token (OAuth 2.0)  
**Rate Limits**: 
- User tweets: 900 requests per 15 minutes
- Tweet lookup: 300 requests per 15 minutes

#### **Key Endpoints Used**:

```ruby
# 1. Fetch User Tweets
GET /2/users/{user_id}/tweets
  ?max_results=100
  &tweet.fields=created_at,public_metrics,entities,lang,source,
                referenced_tweets
  &expansions=author_id,attachments.media_keys
  &media.fields=url,preview_image_url,type
```

```ruby
# 2. Fetch User Info
GET /2/users/{user_id}
  ?user.fields=name,username,profile_image_url,public_metrics,
               description,verified
```

#### **Implementation**: `app/services/twitter_services/`

---

### **OpenAI API (ChatGPT)**

**Endpoint**: `https://api.openai.com/v1`  
**Authentication**: Bearer token (API key)  
**Model**: `gpt-3.5-turbo`  
**Cost**: ~$0.002 per 1K tokens

#### **Use Cases**:

1. **Sentiment Analysis** (`Entry.set_polarity`)
```ruby
prompt = "Analizar el sentimiento de la siguente noticia:
#{title} #{description} #{content}
Responder solo con: negativa, positiva o neutra."
```

2. **Summary Generation** (`ai:generate_ai_reports`)
```ruby
prompt = "En el rol de un analista de PR, resume las siguientes 
noticias relacionadas con #{topic}..."
```

#### **Implementation**: `app/services/ai_services/open_ai_query.rb`

---

## 🔧 Service Layer

### **Service Object Pattern**

All business logic is encapsulated in service objects following this pattern:

```ruby
# app/services/application_service.rb
class ApplicationService
  def self.call(*args, &block)
    new(*args, &block).call
  end
end
```

#### **Response Pattern**:
```ruby
# Success
OpenStruct.new(success?: true, data: {...})

# Failure
OpenStruct.new(success?: false, error: "Error message")
```

---

### **Service Catalog**

#### **Web Extraction Services** (`web_extractor_services/`)

| Service | Purpose | Input | Output |
|---------|---------|-------|--------|
| `ExtractBasicInfo` | Extract title, description, image | Nokogiri doc | Hash |
| `ExtractContent` | Extract article body | Nokogiri doc, CSS selector | Hash |
| `ExtractDate` | Parse publication date | Nokogiri doc | Hash |
| `ExtractTags` | NLP-based tagging | Entry ID | Array of tags |
| `ExtractTitleTags` | Title-only tagging | Entry ID | Array of tags |
| `ExtractBigrams` | Extract word pairs | Entry ID | Array |
| `UrlCrawler` | Crawl single URL | URL string | Entry |

---

#### **Facebook Services** (`facebook_services/`)

| Service | Purpose | Input | Output |
|---------|---------|-------|--------|
| `FanpageCrawler` | Fetch page posts | Page UID, cursor | Hash with posts |
| `UpdatePage` | Update page metadata | Page UID | Hash |
| `UpdateStats` | Fetch FB engagement for entry | Entry ID | Hash with stats |
| `LinkToEntries` | Link posts to articles | - | Count |
| `CommentCrawler` | Fetch post comments (legacy) | Post ID | Array |

---

#### **Twitter Services** (`twitter_services/`)

| Service | Purpose | Input | Output |
|---------|---------|-------|--------|
| `ProcessPosts` | Fetch and process tweets | Profile UID | Hash with posts |
| `GetPostsData` | Fetch tweets (API) | Profile UID | Hash |
| `GetPostsDataAuth` | Fetch tweets (authenticated) | Profile UID | Hash |
| `GetProfileData` | Fetch profile info | Profile UID | Hash |
| `UpdateProfile` | Update profile metadata | Profile UID | Hash |
| `ExtractTags` | NLP tagging for tweets | Tweet text | Array |
| `LinkToEntries` | Link tweets to articles | - | Count |

---

#### **AI Services** (`ai_services/`)

| Service | Purpose | Input | Output |
|---------|---------|-------|--------|
| `OpenAiQuery` | Query OpenAI API | Prompt text | String response |

---

#### **General Dashboard Services** (`general_dashboard_services/`)

| Service | Purpose | Input | Output |
|---------|---------|-------|--------|
| `AggregatorService` | Multi-channel data aggregation | Topic, date range | Comprehensive hash |

---

## 🕷️ Web Scraping Pipeline

### **Anemone Crawler Configuration**

```ruby
Anemone.crawl(
  site.url,
  read_timeout: 10,           # 10 second timeout
  depth_limit: 2,             # Crawl 2 levels deep
  discard_page_bodies: true,  # Memory optimization
  accept_cookies: true,       # Accept cookies
  threads: 5,                 # 5 concurrent threads
  verbose: true,              # Debug output
  user_agent: 'Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36'
)
```

---

### **Crawling Flow**

```
┌──────────────────────────────────────────────────────────────┐
│                    WEB SCRAPING FLOW                          │
└──────────────────────────────────────────────────────────────┘

1. Site Selection
   ↓
   SELECT * FROM sites 
   WHERE status = TRUE 
   AND is_js = FALSE
   ORDER BY total_count DESC
   
2. URL Discovery (Anemone)
   ↓
   Crawl site.url with depth_limit = 2
   Skip: images, PDFs, already-scraped URLs
   Filter: site.filter (e.g., "/noticia/")
   Exclude: site.negative_filter
   
3. Content Extraction (Nokogiri)
   ↓
   For each discovered URL:
   ├─→ ExtractBasicInfo (title, description, image)
   ├─→ ExtractContent (article body, CSS selector)
   ├─→ ExtractDate (published_at)
   └─→ Save Entry
   
4. Tagging (NLP)
   ↓
   ├─→ ExtractTags (full content analysis)
   └─→ ExtractTitleTags (title-only)
   
5. Social Engagement
   ↓
   FacebookServices::UpdateStats
   ├─→ Search Facebook for article URL
   └─→ Fetch reactions, comments, shares
   
6. AI Sentiment Analysis (Optional)
   ↓
   IF entry.belongs_to_any_topic?
     ├─→ OpenAI: "Analizar sentimiento..."
     └─→ Update entry.polarity
```

---

### **URL Filtering Logic**

```ruby
# Skip file types
/.*\.(jpeg|jpg|gif|png|pdf|mp3|mp4|mpeg)/

# Skip common CMS directories
blackhole, wp-login, wp-admin, galerias, fotoblog, 
radios, page, etiqueta, categoria, category, pagina, 
auth, wp-content, img, tag, contacto, programa, date, feed

# Site-specific positive filter (example)
site.filter = "/noticia/"  # Only crawl /noticia/ URLs

# Site-specific negative filter (example)
site.negative_filter = "radio|live|video"
```

---

## 📊 Data Processing Flow

### **Entry Processing Pipeline**

```
New URL Discovered
  ↓
[1] Create Entry (url, site_id)
  ↓
[2] Extract Basic Info
  ├─→ title
  ├─→ description
  └─→ image_url
  ↓
[3] Extract Content
  └─→ content (full article text)
  ↓
[4] Extract Date
  └─→ published_at, published_date
  ↓
[5] NLP Tagging
  ├─→ tag_list (content-based tags)
  └─→ title_tag_list (title-based tags)
  ↓
[6] Facebook Stats
  ├─→ reaction_count
  ├─→ comment_count
  ├─→ share_count
  └─→ total_count (sum)
  ↓
[7] AI Sentiment (if belongs to topic)
  └─→ polarity (negative/neutral/positive)
  ↓
[8] Search Indexing (Elasticsearch)
  └─→ Searchkick reindex
```

---

### **FacebookEntry Processing Pipeline**

```
Facebook API Response
  ↓
[1] Create/Update FacebookEntry
  ├─→ facebook_post_id (unique)
  ├─→ posted_at
  ├─→ message
  ├─→ permalink_url
  └─→ attachment_* fields
  ↓
[2] Reactions (before_save callback)
  ├─→ reactions_like_count
  ├─→ reactions_love_count
  ├─→ reactions_wow_count
  ├─→ reactions_haha_count
  ├─→ reactions_sad_count
  ├─→ reactions_angry_count
  ├─→ reactions_thankful_count
  └─→ reactions_total_count (sum)
  ↓
[3] Sentiment Calculation (before_save)
  ├─→ sentiment_score (weighted)
  ├─→ sentiment_label (enum)
  ├─→ sentiment_*_pct (distribution)
  ├─→ controversy_index
  └─→ emotional_intensity
  ↓
[4] NLP Tagging
  └─→ tag_list (acts_as_taggable_on)
  ↓
[5] Cross-Channel Linking
  └─→ find_matching_entry (by URL)
      └─→ entry_id (optional)
```

---

### **TwitterPost Processing Pipeline**

```
Twitter API Response
  ↓
[1] Create/Update TwitterPost
  ├─→ tweet_id (unique)
  ├─→ posted_at
  ├─→ text
  ├─→ permalink_url
  ├─→ quote_count
  ├─→ reply_count
  ├─→ retweet_count
  ├─→ favorite_count
  ├─→ views_count (actual API data)
  └─→ bookmark_count
  ↓
[2] NLP Tagging
  └─→ tag_list (acts_as_taggable_on)
  ↓
[3] Cross-Channel Linking
  └─→ find_matching_entry (by URL)
      └─→ entry_id (optional)
  ↓
[4] Media Extraction
  ├─→ tweet_images (from payload)
  └─→ external_urls (from entities)
```

---

## 💾 Caching Strategy

### **Cache Layers**

| Layer | Technology | TTL | Use Case |
|-------|------------|-----|----------|
| **Application** | Rails.cache (Redis) | 30 min - 4 hours | Expensive queries |
| **Query** | MySQL query cache | Auto | Identical queries |
| **HTTP** | Browser cache | Session | Static assets |
| **CDN** | (Optional) | 1 hour | Public assets |

---

### **Rails Cache Keys & TTL**

#### **Topic Queries** (30 minutes)
```ruby
Rails.cache.fetch("topic_#{id}_list_entries", expires_in: 30.minutes)
Rails.cache.fetch("topic_#{id}_chart_entries_#{date}", expires_in: 30.minutes)
```

#### **Temporal Intelligence** (2 hours)
```ruby
Rails.cache.fetch("topic_#{id}_peak_times_hour", expires_in: 2.hours)
Rails.cache.fetch("topic_#{id}_fb_sentiment_v2_#{date}", expires_in: 2.hours)
```

#### **Dashboard Aggregations** (30 minutes)
```ruby
Rails.cache.fetch("general_dashboard_#{topic_id}_#{date}", expires_in: 30.minutes)
```

#### **Content Half-Life Analysis** (4 hours)
```ruby
Rails.cache.fetch("topic_#{id}_content_half_life", expires_in: 4.hours)
```

---

### **Cache Invalidation Strategy**

**Automatic Invalidation**:
- Time-based expiration (TTL)
- Model touch cascade (belongs_to touch: true)

**Manual Invalidation**:
```ruby
# Clear all caches for a topic
Rails.cache.delete_matched("topic_#{topic_id}_*")

# Clear specific cache
Rails.cache.delete("general_dashboard_#{topic_id}_#{date}")
```

---

## 🔒 Security & Authentication

### **User Authentication (Devise)**

**Models**:
- `User` - Client users (database_authenticatable, recoverable, rememberable)
- `AdminUser` - Administrators (ActiveAdmin)

**Access Control**:
```ruby
# Topic-based access control
User → UserTopic → Topic

# Controller protection
before_action :authenticate_user!
before_action :verify_topic_access
```

---

### **API Security**

#### **CORS Configuration** (`config/initializers/cors.rb`)
```ruby
Rails.application.config.middleware.insert_before 0, Rack::Cors do
  allow do
    origins '*'
    resource '/api/*',
      headers: :any,
      methods: [:get, :post, :options]
  end
end
```

#### **Content Security Policy** (`config/initializers/content_security_policy.rb`)
- Configured for Highcharts
- Allows inline scripts (Alpine.js)

---

### **Credentials Management**

**Encrypted Credentials** (`config/credentials.yml.enc`):
- OpenAI API key
- Facebook App ID & Secret
- Twitter Bearer Token
- Database password

**Environment Variables** (`.env` via dotenv-rails):
- `FACEBOOK_ACCESS_TOKEN`
- `TWITTER_BEARER_TOKEN`
- `OPENAI_ACCESS_TOKEN`

---

## 📈 Monitoring & Analytics

### **Application Monitoring**

**Elasticsearch** (Searchkick):
- Full-text search on `Entry` model
- Reindexing: `rake reindex_topic`

**PaperTrail** (Audit Log):
- Tracks changes to `Topic` model
- `versions` table stores audit trail

---

### **Performance Metrics**

**Key Metrics to Monitor**:
1. **Crawler Success Rate**: % of successful URL crawls
2. **API Rate Limit Usage**: Facebook & Twitter API calls
3. **Cache Hit Rate**: Redis cache effectiveness
4. **Query Performance**: Slow query log (MySQL)
5. **Background Job Queue**: Sidekiq queue depth
6. **OpenAI API Cost**: Token usage tracking

---

## 🚀 Deployment & Infrastructure

### **Technology Stack**

| Component | Technology | Version |
|-----------|------------|---------|
| **Runtime** | Ruby | 3.1.6 |
| **Framework** | Rails | 7.0.8 |
| **Database** | MySQL | 8.0 |
| **Cache** | Redis | 4.x |
| **Search** | Elasticsearch | 7.17 |
| **Web Server** | Puma | 5.x |
| **Background Jobs** | Whenever (cron) | 1.0 |
| **Process Manager** | puma-daemon | 0.1.2 |

---

### **Production Configuration**

**Time Zone**: `America/Asuncion` (Paraguay)  
**Locale**: `:es` (Spanish)  
**Database Encoding**: `utf8mb4`  
**Rails Environment**: `production`

---

### **Deployment Checklist**

✅ **Before Deploy**:
1. Run migrations: `rails db:migrate RAILS_ENV=production`
2. Compile assets: `rails assets:precompile RAILS_ENV=production`
3. Update crontab: `whenever --update-crontab RAILS_ENV=production`
4. Restart Puma: `pumactl restart`
5. Clear cache: `Rails.cache.clear`

✅ **After Deploy**:
1. Check logs: `tail -f log/production.log`
2. Verify cron: `crontab -l`
3. Test critical endpoints
4. Monitor background jobs

---

## 📚 Key Dependencies (Gemfile)

### **Core**
- `rails` (7.0.4) - Framework
- `mysql2` - Database adapter
- `redis` (4.0) - Cache & sessions
- `puma` (5.0) - Web server

### **Authentication & Admin**
- `devise` (4.8) - User authentication
- `activeadmin` (2.13) - Admin interface
- `paper_trail` (15.1) - Audit trail

### **Data Processing**
- `acts-as-taggable-on` (9.0) - Tagging system
- `searchkick` - Elasticsearch integration
- `groupdate` (6.1) - Time-series grouping

### **Web Scraping**
- `nokogiri` (1.13) - HTML parsing
- `anemone` (0.7.2) - Web crawler
- `selenium-webdriver` - Headless browser
- `httparty` (0.21) - HTTP client

### **Social Media APIs**
- `twitter` (7.0) - Twitter API gem
- (Facebook via HTTParty)

### **AI & NLP**
- `ruby-openai` (4.2) - OpenAI API
- `textmood` (0.1.3) - Sentiment analysis

### **Charts & Visualization**
- `chartkick` (4.2) - Chart generation
- `tailwindcss-rails` (2.0) - CSS framework
- `font-awesome-sass` (6.2) - Icons

### **Scheduling & Jobs**
- `whenever` (1.0) - Cron job management
- `parallel` (1.22) - Parallel processing

### **Development & Testing**
- `rubocop` - Code linting
- `rubocop-rails` - Rails-specific linting
- `debug` - Debugging
- `web-console` - Browser debugging

---

## 🔗 Related Documentation

- **Database Schema**: `/docs/DATABASE_SCHEMA.md`
- **AI Rules**: `/.cursorrules`
- **Performance**: `/docs/implementation/PERFORMANCE_OPTIMIZATION.md`
- **General Dashboard**: `/docs/implementation/GENERAL_DASHBOARD.md`

---

**Last Updated**: November 1, 2025  
**Maintainer**: Morfeo Development Team  
**Status**: Production System - Active Development


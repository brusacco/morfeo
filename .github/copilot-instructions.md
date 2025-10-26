# Morfeo - News Monitoring & Analytics Platform

Morfeo is a Rails 7 news monitoring system that crawls websites, extracts articles, performs sentiment analysis, and generates reports. It's essentially a media intelligence platform for Spanish-language news sources.

## Core Architecture

### Domain Models

- **Entry**: News articles with URL, title, content, sentiment polarity, and social media interaction counts
  - Social metrics: `reaction_count`, `comment_count`, `share_count`, `total_count`
  - Sentiment: `polarity` enum (0: neutral, 1: positive, 2: negative)
  - Content filtering: `repeated` status, `enabled` flag, `category` classification
  - Unique constraint on `url`, belongs to `site`
  - Has many `twitter_posts` for cross-referencing tweets that link to this article
- **FacebookEntry**: Facebook posts from tracked Pages with comprehensive engagement metrics
  - Belongs to `page`, has tagging via `acts-as-taggable-on`
  - Post data: `facebook_post_id` (unique), `posted_at`, `message`, `permalink_url`
  - Attachment data: `attachment_type`, `attachment_title`, `attachment_description`, `attachment_url`, `attachment_target_url`, `attachment_media_src`, dimensions
  - Reaction metrics: Individual counts for like, love, wow, haha, sad, angry, thankful, plus `reactions_total_count`
  - Engagement: `comments_count`, `share_count`, `views_count` (calculated)
  - Views estimation formula: `(likes * 15) + (comments * 40) + (shares * 80) + (followers * 0.04)`
  - Scopes: `recent`, `for_page`, `within_range`, `for_tags`, `for_topic`
  - Analytics methods: `grouped_counts`, `grouped_interactions`, `total_interactions`, `total_views`, `word_occurrences`, `bigram_occurrences`
- **Site**: News websites being monitored with crawling configuration
  - Filters: `filter` (inclusion), `negative_filter` (exclusion), `content_filter` (CSS selector)
  - Status: `status` (enabled/disabled), `is_js` (requires Selenium), `entries_count` cache
  - Media: Base64-encoded `image64` for logos
- **Topic**: Collections of tags for organizing and tracking specific subjects
  - Many-to-many with tags via `tags_topics` join table
  - Sentiment words: `positive_words`, `negative_words` for analysis
  - Has daily statistics via `topic_stat_dailies` and `title_topic_stat_dailies`
- **Tag**: Labels applied to entries for categorization (using `acts-as-taggable-on`)
  - Two contexts: `:tags` (content-based) and `:title_tags` (title-only)
  - Manual variations stored in `variations` field as comma-separated strings
- **Statistical Models**:
  - `TopicStatDaily`: Daily metrics per topic (entry count, interactions, sentiment breakdown)
  - `TitleTopicStatDaily`: Same metrics but for title-tag analysis
  - `Comments`: Facebook comments with `uid`, `message`, linked to entries
  - `Pages`: Facebook page metadata with follower counts and descriptions
- **TwitterProfile**: Twitter account tracking with profile data and metrics
  - Fields: `uid` (Twitter User ID), `username`, `name`, `picture`, `followers`, `description`, `verified`
  - Belongs to `site` (optional), validates uid presence and uniqueness
  - Auto-updates profile data via `TwitterServices::UpdateProfile` after creation
  - Syncs profile picture to associated site
  - Has many `twitter_posts` (tweets from this profile)
- **TwitterPost**: Individual tweets from tracked Twitter profiles with engagement metrics
  - Belongs to `twitter_profile`, has tagging via `acts-as-taggable-on`
  - Belongs to `entry` (optional) for cross-referencing tweets with news articles
  - Post data: `tweet_id` (unique), `posted_at`, `text`, `permalink_url`, `lang`, `source`
  - Engagement metrics: `favorite_count`, `retweet_count`, `reply_count`, `quote_count`, `views_count`, `bookmark_count`
  - Tweet types: `is_retweet`, `is_quote` flags
  - Payload: Full JSON response from Twitter API stored in `payload` field (json column type)
    - **CRITICAL**: Production stores payloads as Ruby hash strings (`=>` syntax), not JSON (`:` syntax)
    - `external_urls` method handles three formats: Hash objects, JSON strings, Ruby hash strings
    - Converts `=>` to `:` before JSON parsing to avoid eval() security risks
  - URL extraction: `external_urls` returns array of expanded URLs from tweet entities
  - Linking: `find_matching_entry`, `link_to_entry!` methods for Entry cross-referencing
  - Scopes: `recent`, `for_profile`, `within_range`, `for_tags`, `for_topic`
  - Analytics methods: `grouped_counts`, `total_interactions`, `word_occurrences`, `bigram_occurrences`
  - Helper methods: `words`, `bigrams`, `tweet_url`, `site` (through profile), `primary_url`, `has_external_url?`

### Key Data Flow

1. **Crawling**: Anemone-based web crawler (`lib/tasks/crawler.rake`) visits sites hourly
2. **Extraction**: Services in `app/services/web_extractor_services/` parse content, dates, tags
3. **Analysis**: OpenAI integration for sentiment analysis and report generation
4. **Social Data**:
   - Facebook Graph API integration for engagement metrics via `FacebookServices::FanpageCrawler`
   - Fetches posts with full reaction breakdowns (like, love, wow, haha, sad, angry, thankful)
   - Calculates estimated views based on engagement formula
   - Stores posts as `FacebookEntry` records with comprehensive metadata
   - Twitter GraphQL API integration for profile and tweet data
   - Fetches tweets with engagement metrics via `TwitterServices::GetPostsData`
   - Processes and stores tweets as `TwitterPost` records
   - Auto-tags tweets using Tag vocabulary via `TwitterServices::ExtractTags`

## Technology Stack & Dependencies

### Core Framework

- **Rails 7.0.4** with Ruby 3.0.0
- **Puma** web server for production deployment
- **Bootsnap** for faster boot times via caching

### Database & Storage

- **SQLite3** (development) / **MySQL2** (production)
- **Redis** for caching and session storage

### Search & Analytics

- **Elasticsearch 7.17** via **Searchkick** gem for full-text search
- **Chartkick** + **Chart.js** for data visualization
- **Groupdate** for time-series data aggregation

### Content Processing & Web Scraping

- **Anemone** for web crawling with queue management
- **Selenium WebDriver** + **Webdrivers** for JavaScript-heavy sites
- **Nokogiri** for HTML/XML parsing
- **Grover** (Chrome headless) for PDF generation
- **Chronic** for natural language date parsing

### AI & External APIs

- **ruby-openai** for ChatGPT integration (sentiment analysis, reports)
- **HTTParty** for HTTP requests and API integrations
- **Twitter** gem for social media integration
- **Telegram-bot-ruby** for bot notifications

### Authentication & Admin

- **Devise** for user authentication (dual system: users + admin_users)
- **ActiveAdmin** + **ActiveAdmin Addons** for content management interface
- **Active Admin Scoped Collection Actions** for bulk operations

### Background Processing & Scheduling

- **Whenever** gem for cron job management
- **Parallel** gem for concurrent processing
- Primarily uses scheduled rake tasks over background queues

### Frontend & Assets

- **Tailwind CSS** via **tailwindcss-rails** for styling
- **Importmap** for JavaScript dependencies (no webpack)
- **Stimulus** + **Turbo** for modern Rails frontend
- **jQuery Rails** for legacy JavaScript components
- **Font Awesome Sass** for icons

### Content Organization & Processing

- **acts-as-taggable-on** for flexible tagging system
- **Textmood** for additional sentiment analysis
- **Paper Trail** for model versioning and audit trails
- **Seed Dump** for database seeding

### Development & Testing

- **Debug** gem for debugging
- **Web Console** for in-browser debugging
- **Capybara** + **Selenium WebDriver** for integration testing
- **Rubocop** + **Rubocop Rails** for code quality
- **dotenv-rails** for loading environment variables from .env file

### API & Data Formats

- **Rabl** for JSON API responses
- **OJ** for fast JSON parsing
- **Rack CORS** for cross-origin requests
- Public API endpoints under `/api/v1/`

### Performance & Caching

- **Action Pack Action Caching** for view caching
- **Puma Daemon** for background process management
- Elasticsearch indexing for fast search

## Service Architecture

### Service Pattern

All services inherit from `ApplicationService` with `.call(...)` class method:

```ruby
# Example usage
result = WebExtractorServices::ExtractTags.call(entry_id)
if result.success?
  # Handle success
else
  puts result.error
end
```

### Key Service Categories

- `AiServices::OpenAiQuery` - ChatGPT integration for sentiment & reports
- `FacebookServices::*` - Social media data extraction
  - `UpdatePage` - Fetches Facebook page metadata (name, username, followers, category, description, picture)
  - `FanpageCrawler` - Crawls Facebook posts from Pages with full engagement metrics
  - `CommentCrawler` - Fetches comments from specific Facebook posts
  - `UpdateStats` - Updates engagement statistics for Entry URLs via Facebook Graph API
- `TwitterServices::*` - Twitter API integration for profile and post data
  - `GetProfileData` - Fetches raw Twitter profile information
  - `GetPostsData` - Retrieves user tweets via Twitter GraphQL API (guest token, fetches up to 100 tweets, may return cached/old data)
  - `GetPostsDataAuth` - **Authenticated API** using session cookies (auth_token, ct0), fetches fresh real-time tweets with pagination (up to 500 tweets across 5 requests)
  - `UpdateProfile` - Extracts and formats profile data for database storage
  - `ProcessPosts` - Extracts and persists tweets from Twitter API responses, automatically uses authenticated API when ENV credentials are present, falls back to guest token
  - `ExtractTags` - Auto-tags tweets using Tag vocabulary with text matching
  - `LinkToEntries` - Batch service to link TwitterPosts to Entries by matching external URLs
- `WebExtractorServices::*` - Content parsing and tag extraction
  - `ExtractFacebookEntryTags` - Tags Facebook entries using existing Tag vocabulary with text matching

## Critical Development Workflows

### Local Development

```bash
bin/dev                    # Start Rails + Tailwind CSS watcher
docker-compose up          # Start Elasticsearch + Redis dependencies
```

### Key Rake Tasks (Production Scheduled)

```bash
rake crawler              # Main web crawler (hourly)
rake headless_crawler     # Selenium-based crawler for JS sites
rake ai:generate_ai_reports # AI-powered topic summaries
rake facebook:fanpage_crawler # Crawl Facebook posts from tracked Pages
rake facebook:entry_tagger    # Tag Facebook entries using Tag vocabulary
rake facebook:update_fanpages # Update Facebook Page metadata (followers, etc.)
rake facebook:comment_crawler # Fetch comments from Facebook posts
rake twitter:update_profiles  # Update Twitter profile stats
rake twitter:profile_crawler  # Crawl tweets from tracked profiles
rake twitter:post_tagger      # Tag Twitter posts using Tag vocabulary
rake twitter:link_to_entries  # Link tweets to news articles by matching URLs
```

### Search & Analytics

- **Elasticsearch**: Uses Searchkick gem for full-text search on entries
- **Charts**: Chartkick + Chart.js for analytics dashboards
- **Admin**: ActiveAdmin interface for content management

### Tweet-to-Entry Cross-Referencing

The system can automatically link tweets to news articles they reference:

1. **URL Extraction**: `TwitterPost#external_urls` extracts URLs from tweet payload entities
2. **Matching Logic**: `TwitterServices::LinkToEntries` finds Entry records with matching URLs
3. **URL Normalization**: Handles URL variations (with/without query params, www, trailing slashes)
4. **Batch Processing**: `rake twitter:link_to_entries` processes all unlinked tweets
5. **Admin UI**: ActiveAdmin shows "Linked" status and allows filtering by Entry

**Key Methods:**

- `TwitterPost#find_matching_entry` - Finds Entry with matching URL
- `TwitterPost#link_to_entry!` - Creates association with Entry
- `TwitterPost#primary_url` - Returns first external URL from tweet
- `TwitterPost#has_external_url?` - Checks if tweet contains URLs

**Expected Metrics:**

- ~70% of tweets contain external URLs
- ~10% of tweets with URLs match existing Entry records
- Matching considers URL variations (with/without www, query params, etc.)

## Project-Specific Conventions

### Database

- Uses both SQLite3 (development) and MySQL2 (production)
- **Entry-centric design**: Core model with social metrics fields (`reaction_count`, `comment_count`, `share_count`, `total_count`)
- **Flexible tagging**: `acts-as-taggable-on` with dual contexts (`:tags`, `:title_tags`) via polymorphic `taggings` table
- **Daily analytics**: Dedicated tables (`topic_stat_dailies`, `title_topic_stat_dailies`) for trend analysis
- **User management**: Separate `users` (frontend) and `admin_users` (ActiveAdmin) with different access levels
- **Content versioning**: PaperTrail integration via `versions` table for audit trails
- **Facebook integration**: `pages` table stores fanpage metadata, `comments` stores social interactions
- **Twitter integration**: `twitter_profiles` table tracks Twitter accounts with profile data (`uid`, `username`, `name`, `picture`, `followers`, `description`, `verified`), `twitter_posts` table stores individual tweets with full engagement metrics (`tweet_id`, `posted_at`, `text`, `favorite_count`, `retweet_count`, `reply_count`, `quote_count`, `views_count`, `bookmark_count`, `is_retweet`, `is_quote`, `payload`, `entry_id`)
  - Cross-referencing: `entry_id` foreign key links tweets to news articles they reference
  - Payload format varies by environment: Hash objects (local), Ruby hash strings with `=>` (production)
- **Newspaper archival**: `newspapers` and `newspaper_texts` for daily content snapshots
- Spanish locale (`config.i18n.default_locale = :es`)

### Content Processing

- **Stop Words**: `stop-words.txt` file filters common Spanish words
- **N-grams**: Bigram/trigram extraction for trend analysis
- **Polarity**: Enum values (neutral: 0, positive: 1, negative: 2)

### Tagging Strategy

- Two separate tag contexts: `:tags` (content-based) and `:title_tags` (title-only)
- AI-powered tag extraction from article content
- Manual tag variations stored as comma-separated strings

### Configuration Files

- `config/schedule.rb` - Cron jobs via whenever gem
- `config/importmap.rb` - JavaScript dependencies without webpack
- `config/tailwind.config.js` - Utility-first CSS framework

## Integration Points

### External APIs

- **OpenAI**: GPT-3.5-turbo for sentiment analysis and report generation
- **Facebook Graph API**: Fetches post engagement metrics and comments
- **Twitter GraphQL API**: Two approaches for fetching tweets
  - **Guest Token API** (`GetPostsData`): Unofficial endpoint, returns cached/old data (up to 100 tweets)
  - **Authenticated API** (`GetPostsDataAuth`): Uses session cookies, returns fresh real-time tweets with pagination (up to 500 tweets)
- **Elasticsearch**: Full-text search with Spanish-language considerations

### Twitter Authentication & Configuration

**Environment Variables** (configured in `.env` file):

- `TWITTER_AUTH_TOKEN` - Session auth_token cookie from logged-in Twitter account
- `TWITTER_CT0_TOKEN` - CSRF token (ct0 cookie) from logged-in session
- `TWITTER_BEARER_TOKEN` - Bearer token for API requests (optional, uses default)

**How to Get Twitter Cookies:**

1. Open Twitter (https://twitter.com) in browser while logged in
2. Open DevTools (F12) → Application/Storage → Cookies → twitter.com
3. Copy values for `auth_token` and `ct0`
4. Add to `.env` file

**Important Notes:**

- Authenticated API fetches **real-time tweets** (much more recent than guest token)
- Session cookies expire periodically and must be refreshed manually
- ProcessPosts service automatically uses authenticated API when credentials are present
- Falls back to guest token API if no credentials found
- Pagination fetches up to 5 pages (~500 tweets total) with 0.5s delay between requests
- See `.env.example` for configuration template

### TwitterPost Payload Parsing

**Critical Implementation Detail**: Production and development environments store tweet payloads in different formats.

**Format Differences:**

- **Development**: Payloads stored as Ruby Hash objects (direct access with `payload['key']`)
- **Production**: Payloads stored as String representation of Ruby hashes with `=>` syntax: `"{\"key\"=>\"value\"}"`
- **Schema**: Database schema defines `payload` as `json` column type, but MySQL stores it as string

**Parsing Implementation** (in `TwitterPost#external_urls`):

```ruby
parsed_payload =
  case payload
  when Hash
    payload  # Local development format
  when String
    if payload.include?('=>')
      # Production Ruby hash string format
      # Convert => to : to make valid JSON
      json_string = payload.gsub('=>', ':')
      JSON.parse(json_string)
    else
      # Standard JSON string format
      JSON.parse(payload)
    end
  end
```

**Why This Matters:**

- URL extraction from tweets depends on parsing nested payload structure
- Production was showing 0% URL extraction until this fix
- Must avoid using `eval()` for security reasons - string replacement is safer
- All methods accessing payload must handle both formats

**Affected Methods:**

- `external_urls` - Extracts URLs from tweet entities
- `primary_url` - Returns first external URL
- `has_external_url?` - Boolean check for URLs
- Any future methods accessing `payload` data

### File Processing

- PDF generation via Grover (Chrome headless)
- Image handling with Base64 encoding for site logos
- Web scraping with configurable CSS selectors per site

## Common Patterns

### Rails Best Practices & Code Standards

This project adheres to Rails best practices and conventions. All code should follow:

- **Rails Conventions**: Follow MVC architecture, RESTful routes, and Rails naming conventions
- **Code Quality**: Use Rubocop for consistent code style and Rails-specific best practices
- **Service Objects**: Follow the established `ApplicationService` pattern for business logic
- **Database Best Practices**: Use proper migrations, indexes, and foreign key constraints
- **Security**: Implement proper parameter filtering, SQL injection prevention, and XSS protection
- **Performance**: Use database indexes, avoid N+1 queries with `includes`, cache expensive operations
- **Testing**: Write comprehensive tests using Rails testing conventions
- **Documentation**: Follow Rails documentation standards and maintain clear code comments

### Development Approach

Act as a senior Ruby on Rails developer. Your role is to analyze, debug, and resolve issues with accuracy and professionalism. To do so:

- **Thorough Analysis**: Review all provided code snippets and files. Never ask the user to confirm the presence of issues—assume full responsibility for identifying problems yourself
- **Verification**: Verify the existence, context, and relevance of all referenced classes, methods, modules, routes, and database fields
- **Documentation**: Consult official Rails documentation and other authoritative sources to ensure every response is technically correct, current, and in line with best practices
- **Logic Tracing**: Trace logical flows, identify edge cases, and consider side effects or unintended consequences in your debugging process
- **Version Awareness**: If an issue could be caused by version differences (e.g., Ruby, Rails, gems), consider version-specific behavior in your analysis
- **Solution Quality**: When suggesting solutions, explain why the fix works, and include any potential risks or trade-offs
- **Validation**: Where helpful, suggest tests, logs, or additional tools to validate and monitor the fix
- **Goal**: Provide the most accurate, efficient, and production-ready solution, minimizing guesswork and maximizing clarity

### Error Handling

Services return `OpenStruct` with `success?` and `data`/`error` attributes rather than raising exceptions.

### Background Processing

Jobs inherit from `ApplicationJob` but most processing runs via scheduled rake tasks rather than queue-based jobs.

### Date Handling

- Timezone: `America/Asuncion`
- Date scopes: `a_day_ago`, `a_week_ago`, `normal_range` (configurable via `DAYS_RANGE`)

### Admin Interface

ActiveAdmin with Spanish labels and custom scoped collection actions for bulk operations. Separate admin authentication system with dedicated `admin_users` table.

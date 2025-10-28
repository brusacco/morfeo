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
  - **Belongs to `entry` (optional)** for cross-referencing Facebook posts with news articles
  - Post data: `facebook_post_id` (unique), `posted_at`, `message`, `permalink_url`
  - Attachment data: `attachment_type`, `attachment_title`, `attachment_description`, `attachment_url`, `attachment_target_url`, `attachment_media_src`, dimensions
  - Reaction metrics: Individual counts for like, love, wow, haha, sad, angry, thankful, plus `reactions_total_count`
  - Engagement: `comments_count`, `share_count`, `views_count` (calculated)
  - Views estimation formula: `(likes * 15) + (comments * 40) + (shares * 80) + (followers * 0.04)`
  - **URL extraction**: `external_urls` returns array of URLs from `attachment_target_url` and `attachment_url`
  - **Linking**: `find_matching_entry`, `link_to_entry!` methods for Entry cross-referencing
  - **URL normalization**: `normalize_url` private method generates URL variations for matching (exact, without query params, without trailing slash, with/without www)
  - **Tag Inheritance**: When linked to an Entry, automatically inherits all Entry tags during tagging process
  - **Word Analysis**: `words` and `bigrams` methods filter content using STOP_WORDS
    - Removes words with length <= 2 characters
    - Filters both words in bigrams against STOP_WORDS
    - Only returns occurrences that appear more than once
  - Scopes: `recent`, `linked`, `unlinked`, `with_url`, `for_page`, `within_range`, `for_tags`, `for_topic`
  - Analytics methods: `grouped_counts`, `grouped_interactions`, `total_interactions`, `total_views`, `word_occurrences`, `bigram_occurrences`
  - Helper methods: `words`, `bigrams`, `primary_url`, `has_external_url?`, `external_urls`
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
  - **Tag Inheritance**: When linked to an Entry, automatically inherits all Entry tags during tagging process
  - **Word Analysis**: `words` and `bigrams` methods filter content using STOP_WORDS
    - Removes words with length <= 2 characters
    - Filters both words in bigrams against STOP_WORDS
    - Only returns occurrences that appear more than once
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
  - `LinkToEntries` - Batch service to link FacebookEntries to Entries by matching external URLs
- `TwitterServices::*` - Twitter API integration for profile and post data
  - `GetProfileData` - Fetches raw Twitter profile information
  - `GetPostsData` - Retrieves user tweets via Twitter GraphQL API (guest token, fetches up to 100 tweets, may return cached/old data)
  - `GetPostsDataAuth` - **Authenticated API** using session cookies (auth_token, ct0), fetches fresh real-time tweets with pagination (up to 500 tweets across 5 requests)
  - `UpdateProfile` - Extracts and formats profile data for database storage
  - `ProcessPosts` - Extracts and persists tweets from Twitter API responses
    - Automatically uses authenticated API when ENV credentials are present, falls back to guest token
    - Parameters: `profile_uid`, `stop_on_duplicates: true/false`, `update_existing: true/false`
    - `stop_on_duplicates: true` (default) - Stops pagination when existing tweet found (fast incremental updates)
    - `stop_on_duplicates: false` - Fetches all available pages regardless of duplicates (full archive crawl)
    - `update_existing: true` - Updates engagement metrics (favorites, retweets, views) for existing tweets
    - `update_existing: false` (default) - Skips existing tweets without updating
  - `ExtractTags` - Auto-tags tweets using Tag vocabulary with text matching, **includes entry tag inheritance** (see below)
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
rake facebook:entry_tagger    # Tag Facebook entries using Tag vocabulary (with entry tag inheritance)
rake facebook:link_to_entries # Link Facebook posts to news articles by matching URLs
rake facebook:update_fanpages # Update Facebook Page metadata (followers, etc.)
rake facebook:comment_crawler # Fetch comments from Facebook posts
rake twitter:update_profiles  # Update Twitter profile stats
rake twitter:profile_crawler  # Crawl tweets from tracked profiles (stops on duplicates)
rake twitter:profile_crawler_full # Full crawl of all tweets, updates existing engagement metrics
rake twitter:post_tagger      # Tag Twitter posts using Tag vocabulary (with entry tag inheritance)
rake twitter:link_to_entries  # Link tweets to news articles by matching URLs
```

### Search & Analytics

- **Elasticsearch**: Uses Searchkick gem for full-text search on entries
- **Charts**: Chartkick + Chart.js for analytics dashboards
- **Admin**: ActiveAdmin interface for content management

### Facebook Post-to-Entry Cross-Referencing

The system can automatically link Facebook posts to news articles they reference:

1. **URL Extraction**: `FacebookEntry#external_urls` extracts URLs from `attachment_target_url` and `attachment_url`
2. **Matching Logic**: `FacebookServices::LinkToEntries` finds Entry records with matching URLs
3. **URL Normalization**: `normalize_url` generates URL variations (exact, without query params, without trailing slash, with/without www)
4. **Batch Processing**: `rake facebook:link_to_entries` processes all unlinked posts
5. **Admin UI**: ActiveAdmin shows "Linked" status with green/red badges and allows filtering by Entry

**Key Methods:**

- `FacebookEntry#find_matching_entry` - Finds Entry with matching URL using normalized variations
- `FacebookEntry#link_to_entry!` - Creates association with Entry
- `FacebookEntry#primary_url` - Returns first external URL (`attachment_target_url` or `attachment_url`)
- `FacebookEntry#has_external_url?` - Checks if post contains URLs
- `FacebookEntry#normalize_url` - Private method generating URL variations for matching

**Expected Metrics:**

- ~99.8% of posts contain external URLs (via attachment fields)
- ~16% of posts with URLs match existing Entry records
- Matching considers URL variations (with/without www, query params, trailing slashes)

**URL Priority:**

1. `attachment_target_url` (preferred - already expanded by Facebook)
2. `attachment_url` (fallback - may be Facebook redirect)

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

### Social Media Tag Inheritance from Entries

The tagging system automatically inherits tags from linked Entry records, ensuring consistency between social posts and the news articles they reference:

**Facebook Tag Inheritance:**

1. **Text Matching**: `WebExtractorServices::ExtractFacebookEntryTags` searches for tags in the post's message, title, description using Tag vocabulary
2. **Entry Tag Inheritance**: If the post has an `entry_id` (linked to a news article), it also pulls all tags from that Entry
3. **Fallback Inheritance**: If text matching fails but post is linked to an Entry with tags, those tags are inherited anyway
4. **Tag Merging**: Both tag sources (text matching + entry tags) are combined and deduplicated
5. **Application**: The final unique tag list is applied to the FacebookEntry

**Twitter Tag Inheritance:**

1. **Text Matching**: `TwitterServices::ExtractTags` first searches for tags in the tweet's text using the Tag vocabulary
2. **Entry Tag Inheritance**: If the tweet has an `entry_id` (linked to a news article), it also pulls all tags from that Entry
3. **Fallback Inheritance**: If text matching fails but tweet is linked to an Entry with tags, those tags are inherited anyway
4. **Tag Merging**: Both tag sources (text matching + entry tags) are combined and deduplicated
5. **Application**: The final unique tag list is applied to the TwitterPost

**Implementation Details:**

```ruby
# In TwitterServices::ExtractTags#call and WebExtractorServices::ExtractFacebookEntryTags#call
if social_post.entry.present?
  entry_tags = social_post.entry.tag_list
  tags_found.concat(entry_tags) if entry_tags.any?
end
```

**Rake Task Fallback Logic:**

```ruby
# In rake facebook:entry_tagger and rake twitter:post_tagger
if !result.success? && social_post.entry.present? && social_post.entry.tag_list.any?
  # Inherit tags from linked entry even if text matching failed
  entry_tags = social_post.entry.tag_list.dup
  social_post.tag_list = entry_tags
  social_post.save!
end
```

**Benefits:**

- **Better Topic Coverage**: Tweets linking to news articles automatically inherit comprehensive article tagging
- **Cross-Platform Consistency**: Tweets and their referenced articles share the same tags for better analytics
- **Reduced Manual Tagging**: Leverages existing Entry tags instead of relying solely on tweet text matching
- **Improved Analytics**: Topic dashboards get more accurate data when tweets inherit proper tags

**Workflow:**

1. `rake twitter:link_to_entries` - Links tweets to entries by URL matching
2. `rake twitter:post_tagger` - Tags tweets (includes entry tag inheritance if linked)
3. Result: Linked tweets have tags from both text analysis and their referenced articles

**Performance Optimization:**

- Rake task uses `.includes(:entry)` to prevent N+1 queries when checking for linked entries
- Enhanced logging shows which tweets benefit from entry tag inheritance

### Twitter Profile Crawling Strategies

The system provides two different crawling modes for Twitter profiles, each optimized for different use cases:

#### Incremental Crawler (`rake twitter:profile_crawler`)

**Purpose**: Fast, efficient daily updates for active profiles

**Behavior**:

- Uses `stop_on_duplicates: true` parameter
- Stops pagination immediately when encountering an existing tweet
- Does NOT update engagement metrics for existing tweets
- Designed for frequent scheduled runs (hourly/daily)

**Use Cases**:

- Regular scheduled crawls to keep up with new tweets
- Profiles that tweet frequently
- Production scheduled tasks
- Minimizing API rate limit usage

**Performance**:

- Fast execution (typically 1-2 API requests per profile)
- Low API quota consumption
- Minimal database operations

#### Full Archive Crawler (`rake twitter:profile_crawler_full`)

**Purpose**: Complete profile analysis and historical metric updates

**Behavior**:

- Uses `stop_on_duplicates: false` and `update_existing: true` parameters
- Fetches all available pages (up to 500 tweets)
- DOES update engagement metrics for existing tweets
- Continues pagination regardless of duplicates

**Use Cases**:

- Initial profile setup and historical tweet import
- Periodic engagement metric refreshes (weekly/monthly)
- Analytics updates to track tweet performance over time
- Backfilling missing tweets

**Performance**:

- Slower execution (up to 5 API requests per profile)
- Higher API quota consumption
- Significant database updates (updates existing records)

**Includes Retry Logic**:

- Up to 3 retries on rate limit errors (429)
- Exponential backoff: 5s, 10s, 15s delays
- Random sleep intervals (30-60s) between profiles

#### Choosing the Right Crawler

| Scenario                 | Recommended Task       | Frequency      |
| ------------------------ | ---------------------- | -------------- |
| Daily tweet monitoring   | `profile_crawler`      | Hourly/Daily   |
| New profile added        | `profile_crawler_full` | Once           |
| Weekly analytics refresh | `profile_crawler_full` | Weekly         |
| Engagement tracking      | `profile_crawler_full` | Weekly/Monthly |
| Backfill missing tweets  | `profile_crawler_full` | As needed      |

**Example Usage**:

```ruby
# Fast incremental update (default behavior)
TwitterServices::ProcessPosts.call(profile_uid)

# Full crawl without metric updates
TwitterServices::ProcessPosts.call(profile_uid, stop_on_duplicates: false)

# Full crawl WITH metric updates (most comprehensive)
TwitterServices::ProcessPosts.call(profile_uid, stop_on_duplicates: false, update_existing: true)
```

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
  - Loaded globally via `config/initializers/stop_words.rb` as `STOP_WORDS` constant
  - Applied to Entry, FacebookEntry, and TwitterPost models for word analysis
  - **Word Filtering**: Removes words with length <= 2 characters and any word in STOP_WORDS list
  - **Bigram Filtering**: Filters bigrams where either word is in STOP_WORDS or <= 2 characters
  - **Occurrence Filtering**: Only shows words/bigrams that appear more than once (`count > 1`)
  - Used in word clouds, frequency tables, and analytics dashboards
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
- `USE_SCRAPE_DO_PROXY` - Set to `true` to use scrape.do proxy service
- `SCRAPE_DO_TOKEN` - API token for scrape.do proxy service

**How to Extract Twitter Authentication Tokens:**

These tokens are required for the authenticated Twitter API which fetches real-time tweets. They come from your browser's session cookies when logged into Twitter.

**Step-by-Step Instructions:**

1. **Log into Twitter**

   - Open your web browser (Chrome, Firefox, Safari, etc.)
   - Go to https://twitter.com
   - Log in with your Twitter account credentials
   - Make sure you're fully logged in and can see your timeline

2. **Open Browser Developer Tools**

   - **Chrome/Edge**: Press `F12` or `Cmd+Option+I` (Mac) / `Ctrl+Shift+I` (Windows/Linux)
   - **Firefox**: Press `F12` or `Cmd+Option+I` (Mac) / `Ctrl+Shift+I` (Windows/Linux)
   - **Safari**: Enable Developer menu in Preferences, then press `Cmd+Option+I`

3. **Navigate to Cookies**

   - Click on the **Application** tab (Chrome/Edge) or **Storage** tab (Firefox/Safari)
   - In the left sidebar, expand **Cookies**
   - Click on **https://twitter.com** (or **https://x.com**)

4. **Find and Copy TWITTER_AUTH_TOKEN**

   - In the cookies list, find the cookie named **`auth_token`**
   - Click on it to view its details
   - Copy the **Value** field (it's a long hexadecimal string, ~40 characters)
   - Example format: `86608d5a44be442c17f10e79c860af1faa4cd9b6`
   - Paste this value into your `.env` file: `TWITTER_AUTH_TOKEN=<your_value>`

5. **Find and Copy TWITTER_CT0_TOKEN**

   - In the same cookies list, find the cookie named **`ct0`**
   - Click on it to view its details
   - Copy the **Value** field (it's a very long hexadecimal string, ~160 characters)
   - Example format: `7af2cd4ac37f2b3f8d80ce8c8fa8928b19eb73e45a8da530ed53168f4fbb1774...`
   - Paste this value into your `.env` file: `TWITTER_CT0_TOKEN=<your_value>`

6. **Verify Your Configuration**
   - Your `.env` file should now have both tokens:
   ```
   TWITTER_AUTH_TOKEN=86608d5a44be442c17f10e79c860af1faa4cd9b6
   TWITTER_CT0_TOKEN=7af2cd4ac37f2b3f8d80ce8c8fa8928b19eb73e45a8da530ed53168f4fbb1774...
   ```
   - Restart any running Rails processes to load the new environment variables

**Token Lifecycle and Maintenance:**

- **Expiration**: Session cookies typically expire after 30-90 days of inactivity
- **Signs of Expiration**:
  - API requests returning 401 Unauthorized errors
  - `TwitterServices::GetPostsDataAuth` failing with authentication errors
  - Rake tasks showing "Authentication failed" messages
- **Refreshing Tokens**: When tokens expire, simply repeat the extraction process with a fresh Twitter login
- **Security**: Never commit `.env` file to git - it's already in `.gitignore`
- **Multiple Accounts**: You can switch accounts by extracting tokens from different Twitter login sessions

**Troubleshooting:**

- **Can't find cookies**: Make sure you're logged into Twitter first
- **Empty cookie value**: The cookie might be HttpOnly - try copying from the Value column in the cookies table
- **Still not working**: Clear your browser cache, log out and back into Twitter, then extract fresh tokens
- **API errors**: Check that both `auth_token` AND `ct0` cookies are present and correctly copied

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

## Topic Analytics Views Architecture

The platform provides comprehensive analytics dashboards for three content sources: **Digitales** (web articles), **Facebook** (fanpage posts), and **Twitter** (tweets). Each follows a consistent pattern with identical features tailored to their respective data models.

### View Pattern: Topic Analytics Dashboard

All three implementations (`TopicController`, `FacebookTopicController`, `TwitterTopicController`) share the same architectural pattern:

#### Controller Structure

**Standard Actions:**

- `show` - Main analytics dashboard with all KPIs and visualizations
- `entries_data` - AJAX endpoint for date-specific drill-down data
- `pdf` - PDF report generation with print-optimized layout

**Standard Setup:**

```ruby
before_action :authenticate_user!
before_action :set_topic
before_action :authorize_topic!
```

**KPI Calculations (show action):**

- Total count (entries/posts/tweets)
- Total interactions (sum of all engagement metrics)
- Total views (calculated or summed)
- Average interactions per item
- Top items by interactions (limit 12 for cards, 10 for PDF)
- Word/bigram frequency analysis
- Tag distribution and interaction breakdown
- Source distribution (sites/pages/profiles)

#### Route Configuration

Each follows RESTful resource pattern with nested routes:

```ruby
resources :topics, only: [:show] do
  get 'entries_data', on: :collection
  get 'pdf', on: :member
end

resources :facebook_topics, only: [:show], controller: 'facebook_topic' do
  get :entries_data, on: :collection
  get :pdf, on: :member
end

resources :twitter_topics, only: [:show], controller: 'twitter_topic' do
  get :entries_data, on: :collection
  get :pdf, on: :member
end
```

#### View Template Structure

**Main View (`show.html.erb`):**

1. **Header Section** - Page title, breadcrumbs, PDF generation button
2. **KPI Cards Grid** - 4 cards showing primary metrics
3. **Temporal Charts** - Posts/day and Interactions/day (column charts)
4. **Tag Analysis** - Pie charts for tag distribution and interactions
5. **Word Clouds** - Visual word frequency with sentiment coloring
6. **Word/Bigram Lists** - Frequency tables with counts
7. **Source Analysis** - Pie charts for content source distribution
8. **DataTables** - Sortable/searchable table with all items
9. **Top Cards Grid** - Visual cards of top performing content

**Required Partials:**

- `_[item].html.erb` - Individual item card (entry/facebook_entry/twitter_post)
- `_[items].html.erb` - Grid container wrapper
- `_posts_table.html.erb` - DataTables implementation
- `_chart_entries.html.erb` - Date-specific drill-down data
- `pdf.html.erb` - Print-optimized report layout

#### Metrics Mapping

**Digitales (Entry):**

- Engagement: `reaction_count`, `comment_count`, `share_count`, `total_count`
- Sources: News sites (`Site` model)
- Linking: `site.name`, `site.url`

**Facebook (FacebookEntry):**

- Engagement: `reactions_total_count`, `comments_count`, `share_count`, `views_count`
- Reaction breakdown: `like`, `love`, `wow`, `haha`, `sad`, `angry`, `thankful`
- Sources: Facebook Pages (`Page` model)
- Linking: `page.name`, `page.username`, `permalink_url`
- Views formula: `(likes * 15) + (comments * 40) + (shares * 80) + (followers * 0.04)`

**Twitter (TwitterPost):**

- Engagement: `favorite_count`, `retweet_count`, `reply_count`, `quote_count`, `views_count`, `bookmark_count`
- Total calculation: `favorite_count + retweet_count + reply_count + quote_count`
- Sources: Twitter Profiles (`TwitterProfile` model)
- Linking: `twitter_profile.name`, `twitter_profile.username`, `tweet_url`
- Tweet URL: `https://twitter.com/#{username}/status/#{tweet_id}`

#### Navigation Integration

**Navbar Dropdown Pattern** (`app/views/layouts/_nav.html.erb`):

Three dropdown menus in header navigation:

1. **Digitales** - Digital news topics (indigo colors)
2. **Facebook** - Facebook topics (blue colors)
3. **Twitter** - Twitter topics (sky blue colors)

Each dropdown:

- Displays all active topics assigned to current user
- Highlights active topic when viewing
- Closes other dropdowns when opening
- Closes on outside click

**JavaScript Implementation** (`app/javascript/application.js`):

```javascript
// Each dropdown has:
var [name]TopicsMenuButton = document.getElementById('[name]-topics-menu-button');
var [name]TopicsMenu = document.getElementById('[name]-topics-menu');

// Toggle behavior with cross-closing
[name]TopicsMenuButton.addEventListener('click', function(event) {
  [name]TopicsMenu.classList.toggle('hidden');
  // Close other dropdowns
  if (otherMenu && !otherMenu.classList.contains('hidden')) {
    otherMenu.classList.add('hidden');
  }
  event.stopPropagation();
});

// Global click handler closes all dropdowns
document.addEventListener('click', function() {
  if ([name]TopicsMenu && ![name]TopicsMenu.classList.contains('hidden')) {
    [name]TopicsMenu.classList.add('hidden');
  }
});
```

#### DataTables Implementation

**Standard Configuration:**

- **Language**: Spanish (`buscar`, `mostrar`, `entradas`, etc.)
- **Pagination**: 25 items per page default, options for 10/25/50/100/All
- **Sorting**: Default by date descending
- **Search**: All columns, Spanish placeholder
- **Responsive**: Mobile-friendly column hiding
- **Styling**: Tailwind CSS integration with custom pagination

**Column Structure:**

- Date (sortable by timestamp, formatted display)
- Content/Message (truncated with link)
- Tags (badge display, max 3 visible)
- Source (site/page/profile with username)
- Engagement metrics (color-coded icons)
- Total interactions (bold emphasis)

**Custom Styling:**

- Override default DataTables CSS for pagination
- Tailwind-styled buttons and controls
- Focus states for accessibility
- Responsive grid layout
- Color-coded metrics (red/green/blue/amber/sky)

#### PDF Report Generation

**Technology**: Grover gem (Chrome headless) for HTML-to-PDF conversion

**Layout Optimization:**

- A4 page size with 2cm margins
- Page break controls (`page-break-before`, `page-break-inside: avoid`)
- Print-specific font sizes (pt units)
- Chart sizing optimized for print (200px height)
- Color preservation (`print-color-adjust: exact`)

**Report Sections:**

1. Header with topic name and date range
2. KPI statistics grid
3. Temporal evolution charts (2 columns)
4. Summary paragraph with key insights
5. Tag analysis charts
6. Source analysis (sites/pages/profiles)
7. Top items with detailed metrics
8. Word cloud visualization
9. Auto-print JavaScript trigger

**Chart Rendering:**

- Chartkick with Highcharts adapter
- DataLabels enabled for print clarity
- Color schemes matching web version
- Donut charts for distributions
- Column charts for time series

#### Color Schemes & Branding

**Digitales (Articles):**

- Primary: Indigo (`#4f46e5`, `bg-indigo-600`)
- Accents: Blue, Green, Purple
- Icons: Newspaper, Link, Building

**Facebook:**

- Primary: Blue (`#3b82f6`, `bg-blue-600`)
- Reaction colors: Blue (like), Red (love), Yellow (haha), etc.
- Icons: Facebook brand, Building, Calendar

**Twitter:**

- Primary: Sky Blue (`#0ea5e9`, `bg-sky-600`)
- Engagement colors: Red (favorites), Green (retweets), Blue (replies)
- Icons: Twitter brand, User, Heart, Retweet

#### Model Methods Required

Each model (`Entry`, `FacebookEntry`, `TwitterPost`) must implement:

**Class Methods:**

```ruby
def self.for_topic(topic, start_time:, end_time:)
  # Filter by topic tags and date range
end

def self.grouped_counts(scope, format: '%d/%m')
  # Daily counts for chart
end

def self.grouped_interactions(scope, format: '%d/%m')
  # Daily interaction totals for chart
end

def self.total_interactions(scope)
  # Sum of all engagement metrics
end

def self.total_views(scope)
  # Sum of views (if applicable)
end

def self.word_occurrences(scope, limit = 100)
  # Word frequency analysis
end

def self.bigram_occurrences(scope, limit = 100)
  # Bigram frequency analysis
end
```

**Instance Methods:**

```ruby
def total_interactions
  # Sum of engagement metrics for this item
end

def words
  # Tokenize text, filter stop words
end

def bigrams
  # Two-word phrases from text
end
```

#### Helper Methods Used

**ApplicationHelper:**

- `number_with_delimiter` - Format large numbers
- `truncate` - Shorten long text
- `time_ago_in_words` - Relative timestamps

**ReportsHelper:**

- `prepare_word_cloud_data` - Format words with weights and colors
- `word_color` - Sentiment-based coloring (positive/negative/neutral)
- `find_max_and_min_occurrences` - Normalization for word cloud
- `normalize_to_scale` - Scale word sizes 1-10

#### Authentication & Authorization

**User Authentication:**

- Devise gem with `User` model
- `before_action :authenticate_user!` on all controllers
- Separate `admin_users` for ActiveAdmin

**Topic Authorization:**

- Topics have `status` (enabled/disabled)
- Topics linked to users via `topics_users` join table
- Authorization checks: `topic.status && topic.users.exists?(current_user.id)`
- Redirect to root with alert if unauthorized

#### Dependencies

**Frontend:**

- jQuery 3.7.1 (DataTables dependency)
- DataTables 1.13.6 (table sorting/search)
- Chartkick 4.2.0 (chart abstraction)
- Highcharts 10.3.2 (chart rendering)
- Tailwind CSS (styling)
- Font Awesome (icons)

**Backend:**

- Groupdate gem (date aggregation)
- Acts-as-taggable-on (tagging)
- Grover (PDF generation)
- Turbo Rails (navigation)

### Implementation Checklist

When adding a new analytics view type:

1. ✅ Create controller with `show`, `entries_data`, `pdf` actions
2. ✅ Add RESTful routes with nested paths
3. ✅ Create view directory: `app/views/[name]_topic/`
4. ✅ Implement partials: `_item.html.erb`, `_items.html.erb`, `_posts_table.html.erb`, `_chart_entries.html.erb`
5. ✅ Create main `show.html.erb` with all sections
6. ✅ Create `pdf.html.erb` for print layout
7. ✅ Add navbar dropdown in `_nav.html.erb`
8. ✅ Add JavaScript dropdown handlers in `application.js`
9. ✅ Update model with required class/instance methods
10. ✅ Test authentication, authorization, data display
11. ✅ Verify DataTables functionality (sort, search, pagination)
12. ✅ Test PDF generation and layout
13. ✅ Verify responsive design (mobile/tablet/desktop)
14. ✅ Check chart rendering and interactions
15. ✅ Validate Spanish translations throughout

## Twitter Analytics Implementation

### Overview

The Twitter analytics implementation provides a comprehensive dashboard for analyzing tweets from tracked Twitter profiles, mirroring the existing Facebook analytics but tailored for Twitter's engagement model and real-time API data.

### Architecture Components

#### Controller: `TwitterTopicController`

**Location**: `app/controllers/twitter_topic_controller.rb`

**Purpose**: Handles Twitter topic analytics display, data aggregation, and PDF report generation.

**Key Features**:

- Authentication via Devise (`before_action :authenticate_user!`)
- Topic authorization checking user access and topic status
- Date range filtering (default: last 7 days via `DAYS_RANGE` constant)
- KPI calculations (total posts, interactions, views, averages)
- Word/bigram frequency analysis for content trends
- Profile distribution analysis
- AJAX endpoints for date-specific drill-down

**Actions**:

1. **`show`** - Main analytics dashboard

   - Filters `TwitterPost` records by topic tags and date range
   - Calculates key metrics:
     - `@total_posts` - Total tweet count
     - `@total_interactions` - Sum of favorites, retweets, replies, quotes
     - `@total_views` - Sum of actual view counts from Twitter API
     - `@average_interactions` - Mean interactions per tweet
   - Aggregates temporal data for charts (posts/day, interactions/day)
   - Extracts word frequencies for word cloud visualization
   - Groups tweets by profile for distribution analysis
   - Identifies top 12 tweets by total interactions

2. **`entries_data`** - AJAX endpoint for date-specific data

   - Accepts `date` parameter (format: `DD/MM/YYYY`)
   - Returns tweets posted on specific date
   - Renders `_chart_entries.html.erb` partial

3. **`pdf`** - Generates PDF report
   - Same data aggregation as `show` action
   - Limits top tweets to 10 (vs 12 in web view)
   - Renders `pdf.html.erb` template
   - Uses Grover gem for HTML-to-PDF conversion
   - Configures A4 page size with 2cm margins

**Authorization Logic**:

```ruby
def authorize_topic!
  return if @topic.status && @topic.users.exists?(current_user.id)

  redirect_to root_path, alert: 'No tienes acceso a este tema.'
end
```

#### Routes Configuration

**Location**: `config/routes.rb`

**Pattern**: RESTful resources with nested custom actions

```ruby
resources :twitter_topics, only: [:show], controller: 'twitter_topic' do
  get :entries_data, on: :collection
  get :pdf, on: :member
end
```

**Generated Routes**:

- `GET /twitter_topics/:id` - Main dashboard (`twitter_topic#show`)
- `GET /twitter_topics/entries_data?date=DD/MM/YYYY` - Date drill-down (`twitter_topic#entries_data`)
- `GET /twitter_topics/:id/pdf` - PDF report (`twitter_topic#pdf`)

#### Model: `TwitterPost`

**Location**: `app/models/twitter_post.rb`

**Required Methods for Analytics**:

**Class Methods**:

- `for_topic(topic, start_time:, end_time:)` - Filters tweets by topic tags and date range
- `grouped_counts(scope, format: '%d/%m')` - Daily tweet counts for temporal charts
- `grouped_interactions(scope, format: '%d/%m')` - Daily interaction totals
- `total_interactions(scope)` - Sum of all engagement metrics across scope
- `total_views(scope)` - Sum of view counts (from Twitter API)
- `word_occurrences(scope, limit = 100)` - Word frequency hash for word cloud
- `bigram_occurrences(scope, limit = 100)` - Two-word phrase frequencies

**Instance Methods**:

- `total_interactions` - Sum of favorite, retweet, reply, quote counts
- `words` - Tokenizes tweet text, filters Spanish stop words
- `bigrams` - Extracts two-word phrases using `each_cons(2)`
- `tweet_url` - Generates Twitter permalink: `https://twitter.com/{username}/status/{tweet_id}`
- `site` - Returns associated Site through TwitterProfile relationship

**Key Associations**:

- `belongs_to :twitter_profile` - Twitter account that posted the tweet
- `belongs_to :entry, optional: true` - Links to news article if tweet references one
- `acts_as_taggable_on :tags` - Flexible tagging for topic assignment

**Engagement Metrics Fields**:

- `favorite_count` - Likes/hearts (primary engagement)
- `retweet_count` - Retweets/shares
- `reply_count` - Direct replies
- `quote_count` - Quote tweets
- `views_count` - **Actual view count from Twitter API** (not calculated)
- `bookmark_count` - Saved bookmarks

**Data Source**:

- All metrics come directly from Twitter GraphQL API
- `views_count` is real API data, unlike Facebook's estimated formula
- Extracted in `TwitterServices::ProcessPosts` line 109: `views_count: views.present? ? Integer(views, 10) : 0`

### View Templates

#### Main Dashboard: `show.html.erb`

**Location**: `app/views/twitter_topic/show.html.erb`

**Layout Structure** (9 sections):

1. **Header Section**

   - Page title: "Twitter - [Topic Name]"
   - Breadcrumb navigation
   - PDF generation button (opens in new tab)

2. **KPI Cards Grid** (4 cards, 2x2 grid)

   - Total Posts (sky-600 background, Twitter bird icon)
   - Total Interactions (green-600 background, trending up icon)
   - Total Views (amber-600 background, eye icon)
   - Average Interactions (blue-600 background, chart bar icon)
   - All cards show formatted numbers with delimiters

3. **Temporal Charts Row** (2 column layout)

   - **Posts by Day**: Column chart showing daily tweet volume
   - **Interactions by Day**: Column chart showing engagement trends
   - Both use Chartkick with Highcharts adapter
   - Date format: `DD/MM/YYYY`
   - Charts are clickable for drill-down to specific dates

4. **Tag Analysis Row** (2 donut charts)

   - **Tag Distribution**: Shows tag frequency across tweets
   - **Tag Interactions**: Shows engagement by tag
   - Both use pie chart visualization
   - Color scheme: blue gradient palette

5. **Word Cloud Section**

   - Visual representation of most frequent words
   - Font sizes scaled 1-10 based on frequency
   - Sentiment-based coloring:
     - Green: Positive sentiment words
     - Red: Negative sentiment words
     - Gray: Neutral words
   - Implemented with `prepare_word_cloud_data` helper

6. **Word Frequency Tables** (2 column layout)

   - **Top Words**: Most common single words (limit 100)
   - **Top Bigrams**: Most common two-word phrases (limit 100)
   - Each shows word/phrase and occurrence count
   - Responsive design with max height and scrolling

7. **Profile Distribution Row** (2 donut charts)

   - **Tweets by Profile**: Shows which accounts post most
   - **Interactions by Profile**: Shows which accounts get most engagement
   - Grouped by `twitter_profile.name`
   - Helps identify most influential sources

8. **DataTables Section**

   - Sortable/searchable table of all tweets
   - Default sort: Date descending (most recent first)
   - Spanish localization for all UI elements
   - Pagination: 25 per page (10/25/50/100/All options)
   - Custom Tailwind styling for controls
   - Renders `_posts_table.html.erb` partial

9. **Top Tweets Grid**
   - Visual cards of top 12 tweets by total interactions
   - 3-column responsive grid (lg:grid-cols-3)
   - Each card shows profile, tweet text, engagement metrics
   - Renders via `_twitter_posts.html.erb` partial

**Chart Interactions**:

- Clicking a date on charts triggers AJAX request to `entries_data`
- Modal displays tweets from that specific date
- Modal uses Tailwind modal pattern with backdrop

**Styling**:

- Primary color: Sky blue (`bg-sky-600`, `text-sky-600`)
- Secondary colors: Green (interactions), Amber (views), Blue (averages)
- Responsive breakpoints: sm, md, lg, xl
- Consistent spacing with Tailwind utilities

#### Tweet Card Partial: `_twitter_post.html.erb`

**Location**: `app/views/twitter_topic/_twitter_post.html.erb`

**Purpose**: Displays individual tweet in card format

**Card Structure**:

1. **Header**

   - Profile picture (circular, 48x48px)
   - Fallback to Twitter logo if no picture
   - Profile name and username
   - Posted date with `time_ago_in_words`

2. **Tweet Content**

   - Truncated text (200 characters max)
   - Linked to tweet URL (opens in new tab)
   - External link icon

3. **Engagement Metrics Grid** (3 rows x 2 cols)

   - ❤️ Favorites (red icon) - Right-aligned count
   - 🔁 Retweets (green icon) - Right-aligned count
   - 💬 Replies (blue icon) - Right-aligned count
   - 👁️ Views (amber icon) - Right-aligned count
   - 📊 Total (gray icon, bold) - Right-aligned count
   - Each metric has Font Awesome icon + formatted number

4. **Tags Section**
   - Sky-blue badges for each tag
   - Limit of 2 tags displayed (`.first(2)`)
   - Prevents visual clutter in grid layout

**Styling**:

- White background with shadow (`bg-white shadow-md`)
- Rounded corners (`rounded-lg`)
- Hover effect (`hover:shadow-lg`)
- Consistent padding and spacing
- Color-coded metrics for quick scanning

#### Grid Container Partial: `_twitter_posts.html.erb`

**Location**: `app/views/twitter_topic/_twitter_posts.html.erb`

**Purpose**: Wraps tweet cards in responsive grid

**Grid Configuration**:

- Single column on mobile (default)
- 2 columns on medium screens (`md:grid-cols-2`)
- 3 columns on large screens (`lg:grid-cols-3`)
- Gap between cards (`gap-6`)

**Usage**:

```erb
<%= render 'twitter_posts', twitter_posts: @top_twitter_posts %>
```

#### DataTables Partial: `_posts_table.html.erb`

**Location**: `app/views/twitter_topic/_posts_table.html.erb`

**Purpose**: Sortable/searchable table of all tweets

**Column Structure** (9 columns):

1. **Fecha** - Date/time with formatted display, sortable by `data-order` timestamp
2. **Tweet** - Truncated text (100 chars) with link to tweet
3. **Tags** - Badge display, max 3 tags visible
4. **Perfil** - Profile name with username in parentheses
5. **❤️ Favoritos** - Favorite count with red icon
6. **🔁 Retweets** - Retweet count with green icon
7. **💬 Respuestas** - Reply count with blue icon
8. **👁️ Vistas** - View count with amber icon (from Twitter API)
9. **📊 Total** - Total interactions (bold, gray icon)

**DataTables Configuration**:

```javascript
$(document).ready(function () {
  $("#twitter-posts-table").DataTable({
    language: {
      search: "Buscar:",
      lengthMenu: "Mostrar _MENU_ entradas",
      info: "Mostrando _START_ a _END_ de _TOTAL_ entradas",
      paginate: {
        first: "Primero",
        last: "Último",
        next: "Siguiente",
        previous: "Anterior",
      },
    },
    order: [[0, "desc"]], // Sort by date descending
    pageLength: 25,
    lengthMenu: [
      [10, 25, 50, 100, -1],
      [10, 25, 50, 100, "Todos"],
    ],
    responsive: true,
  });
});
```

**Custom Styling**:

- Overrides default DataTables pagination CSS
- Tailwind-styled buttons (`bg-sky-500`, `hover:bg-sky-700`)
- Focus states for accessibility
- Responsive table wrapper with horizontal scroll on mobile
- Consistent color scheme with dashboard

#### Drill-Down Partial: `_chart_entries.html.erb`

**Location**: `app/views/twitter_topic/_chart_entries.html.erb`

**Purpose**: Displays tweets from specific date (AJAX response)

**Layout**:

- Header showing selected date
- List of tweets with basic info:
  - Profile name and username
  - Tweet text with link
  - Engagement metrics (favorites, retweets, replies, views)
  - Posted time with `time_ago_in_words`
- Consistent styling with main cards

**AJAX Integration**:

```javascript
// Chart click handler
chart.on("click", function (e) {
  var date = e.point.category; // Gets date from clicked point
  fetch(`/twitter_topics/entries_data?date=${date}`)
    .then((response) => response.text())
    .then((html) => {
      // Display in modal
      document.getElementById("modal-content").innerHTML = html;
      openModal();
    });
});
```

#### PDF Report Template: `pdf.html.erb`

**Location**: `app/views/twitter_topic/pdf.html.erb`

**Purpose**: Print-optimized report layout for PDF generation

**Key Differences from Web View**:

- A4 page size with 2cm margins
- Print-specific font sizes (pt units instead of rem)
- Page break controls (`page-break-before`, `page-break-inside: avoid`)
- Reduced top tweets to 10 (vs 12 in web view)
- No interactive elements (no DataTables, no click handlers)
- Chart height: 200px (optimized for print)
- Color preservation: `print-color-adjust: exact`

**Report Sections**:

1. Header: Topic name and date range
2. KPI Statistics: 2x2 grid with metrics
3. Temporal Charts: Posts/day and interactions/day side-by-side
4. Summary Paragraph: Narrative overview of topic performance
5. Tag Analysis: Distribution and interaction pie charts
6. Profile Analysis: Tweet and interaction distribution
7. Top Tweets: 10 highest-performing tweets with full details
8. Word Cloud: Visual word frequency representation

**Auto-Print Trigger**:

```javascript
<script>
  window.onload = function() {
    setTimeout(function() {
      window.print();
    }, 1000); // 1 second delay for chart rendering
  };
</script>
```

**Grover Configuration** (in controller):

```ruby
respond_to do |format|
  format.html do
    render layout: false, template: 'twitter_topic/pdf'
  end
end
```

### Navigation Integration

#### Navbar Dropdown

**Location**: `app/views/layouts/_nav.html.erb`

**Added Component**: Twitter topics dropdown menu

**Visual Design**:

- Sky-blue button (`bg-sky-500`, `hover:bg-sky-700`)
- Twitter bird icon (Font Awesome)
- Chevron down indicator (animated on open)
- Dropdown menu with white background and shadow

**Dropdown Menu Structure**:

```erb
<div class="relative inline-block text-left">
  <button id="twitter-topics-menu-button" class="bg-sky-500 hover:bg-sky-700 text-white...">
    <i class="fab fa-twitter mr-2"></i>
    Twitter
    <svg class="ml-2 h-5 w-5"><!-- Chevron icon --></svg>
  </button>

  <div id="twitter-topics-menu" class="hidden absolute right-0 mt-2 w-56...">
    <% current_user.topics.where(status: true).each do |topic| %>
      <%= link_to twitter_topic_path(topic), class: "block px-4 py-2..." do %>
        <%= topic.name %>
      <% end %>
    <% end %>
  </div>
</div>
```

**Active State Highlighting**:

- Current topic shown with darker background
- Conditional class: `<%= 'bg-sky-100' if @topic == topic %>`

**Positioning**:

- Placed after Facebook dropdown in navbar
- Consistent spacing and alignment with other dropdowns
- Responsive: Stacks vertically on mobile

#### JavaScript Dropdown Handlers

**Location**: `app/javascript/application.js`

**Purpose**: Handle dropdown toggle behavior and cross-menu closing

**Implementation**:

```javascript
// Twitter dropdown elements
var twitterTopicsMenuButton = document.getElementById(
  "twitter-topics-menu-button"
);
var twitterTopicsMenu = document.getElementById("twitter-topics-menu");

// Toggle Twitter dropdown
if (twitterTopicsMenuButton) {
  twitterTopicsMenuButton.addEventListener("click", function (event) {
    twitterTopicsMenu.classList.toggle("hidden");

    // Close other dropdowns when Twitter opens
    if (
      digitalesTopicsMenu &&
      !digitalesTopicsMenu.classList.contains("hidden")
    ) {
      digitalesTopicsMenu.classList.add("hidden");
    }
    if (
      facebookTopicsMenu &&
      !facebookTopicsMenu.classList.contains("hidden")
    ) {
      facebookTopicsMenu.classList.add("hidden");
    }

    event.stopPropagation();
  });
}

// Global click handler - close all dropdowns on outside click
document.addEventListener("click", function (event) {
  if (twitterTopicsMenu && !twitterTopicsMenu.classList.contains("hidden")) {
    twitterTopicsMenu.classList.add("hidden");
  }
});

// Prevent dropdown from closing when clicking inside it
if (twitterTopicsMenu) {
  twitterTopicsMenu.addEventListener("click", function (event) {
    event.stopPropagation();
  });
}
```

**Behavior**:

- Click button: Toggle dropdown visibility
- Click outside: Close all dropdowns
- Click inside dropdown: Keep open (for submenu navigation)
- Opening one dropdown: Automatically closes others
- Smooth user experience with no menu conflicts

### Color Scheme & Branding

**Primary Color**: Sky Blue

- Buttons: `bg-sky-500`, `hover:bg-sky-700`
- Text: `text-sky-600`, `text-sky-800`
- Borders: `border-sky-300`
- Backgrounds: `bg-sky-50`, `bg-sky-100`

**Metric Colors** (consistent across all views):

- Favorites: Red (`text-red-500`, `text-red-600`)
- Retweets: Green (`text-green-500`, `text-green-600`)
- Replies: Blue (`text-blue-500`, `text-blue-600`)
- Views: Amber (`text-amber-500`, `text-amber-600`)
- Total: Gray (`text-gray-600`, bold)

**Icons**:

- Twitter brand icon: `fab fa-twitter`
- User profile: `fas fa-user`
- External link: `fas fa-external-link-alt`
- Heart (favorites): `fas fa-heart`
- Retweet: `fas fa-retweet`
- Comment (replies): `fas fa-comment`
- Eye (views): `fas fa-eye`
- Chart: `fas fa-chart-bar`

### Data Flow & Performance

#### Query Optimization

**Eager Loading**:

```ruby
@twitter_posts = TwitterPost.for_topic(@topic, start_time: @start_time, end_time: @end_time)
                            .includes(twitter_profile: :site)
```

**Purpose**: Prevents N+1 queries when accessing profile and site data in views

**Scoped Queries**:

- `for_topic(topic, start_time:, end_time:)` - Combines tag filtering and date range
- `for_tags(tag_names)` - Uses `acts-as-taggable-on` efficiently
- `within_range(start_time, end_time)` - Indexed timestamp query
- `recent` - Orders by `posted_at DESC`

#### Aggregation Strategy

**Class Method Approach**:

- All aggregations done at model level, not in controller
- Uses `group_by_day` from Groupdate gem for temporal grouping
- Direct SQL aggregation with `sum()` and `count()` for efficiency
- `except(:includes)` to avoid eager loading in aggregation queries

**Word Analysis**:

- Processes tweets in batches with `find_each`
- Uses Ruby hash for frequency counting (in-memory)
- Filters stop words from `stop-words.txt` file
- Results sorted and limited to top 100

#### Caching Considerations

**No Explicit Caching** (yet):

- Real-time data expected (Twitter API updates frequently)
- Date range typically limited to 7 days (reasonable query size)
- Consider fragment caching for:
  - Word cloud data (expensive calculation)
  - Tag distribution charts (stable data)
  - Profile distribution (changes slowly)

**Future Optimization**:

```ruby
# Potential cache keys
cache_key = "twitter_topic_#{@topic.id}_#{@start_time.to_date}_#{@end_time.to_date}"
@word_occurrences = Rails.cache.fetch("#{cache_key}/words", expires_in: 1.hour) do
  TwitterPost.word_occurrences(@twitter_posts)
end
```

### Testing & Validation

#### Manual Testing Checklist

1. **Authentication**: ✅

   - Unauthenticated users redirected to login
   - Users without topic access see authorization error

2. **Data Display**: ✅

   - KPI cards show correct totals
   - Charts render with proper data
   - Tables display all tweets
   - Top tweets show highest engagement

3. **Interactions**: ✅

   - Chart clicks trigger date drill-down
   - Modal displays correct filtered data
   - Dropdown menus toggle properly
   - External links open in new tabs

4. **PDF Generation**: ✅

   - PDF renders all sections correctly
   - Charts appear in print version
   - Page breaks work properly
   - Auto-print triggers after load

5. **Responsive Design**: ✅

   - Mobile: Single column layout
   - Tablet: 2-column grid
   - Desktop: 3-column grid
   - Tables scroll horizontally on small screens

6. **Spanish Localization**: ✅
   - All UI text in Spanish
   - DataTables messages in Spanish
   - Date formats: DD/MM/YYYY
   - Number formatting with delimiters

#### Database Queries

**Index Requirements**:

```sql
-- Existing indexes in schema
CREATE INDEX index_twitter_posts_on_twitter_profile_id;
CREATE INDEX index_twitter_posts_on_entry_id;
CREATE INDEX index_twitter_posts_on_tweet_id;
CREATE INDEX index_twitter_posts_on_posted_at; -- For date range queries

-- Taggings index (from acts-as-taggable-on)
CREATE INDEX index_taggings_on_taggable_type_and_taggable_id;
CREATE INDEX index_taggings_on_tag_id;
```

**Query Performance**:

- Topic filtering: Uses taggings index efficiently
- Date range: Uses posted_at index
- Profile grouping: Uses twitter_profile_id index
- Entry linking: Uses entry_id index for cross-references

### Comparison: Twitter vs Facebook Analytics

#### Similarities

1. **Architectural Pattern**: Both follow identical controller/view structure
2. **KPI Layout**: Same 4-card grid pattern
3. **Chart Types**: Same temporal and distribution charts
4. **DataTables**: Identical configuration and styling
5. **PDF Reports**: Same layout and sections
6. **Navigation**: Same dropdown menu pattern
7. **Authorization**: Same user access checking

#### Key Differences

| Aspect                 | Twitter                                 | Facebook                                                |
| ---------------------- | --------------------------------------- | ------------------------------------------------------- |
| **Model**              | `TwitterPost`                           | `FacebookEntry`                                         |
| **Source**             | `TwitterProfile`                        | `Page`                                                  |
| **Primary Metric**     | Favorites (❤️)                          | Reactions (various emojis)                              |
| **Views Data**         | **Real API data**                       | **Calculated estimate**                                 |
| **Views Formula**      | Direct from API                         | `(likes*15)+(comments*40)+(shares*80)+(followers*0.04)` |
| **Total Calculation**  | favorites + retweets + replies + quotes | reactions + comments + shares                           |
| **Additional Metrics** | quote_count, bookmark_count             | Reaction breakdown (7 types)                            |
| **Content Field**      | `text`                                  | `message`                                               |
| **URL Format**         | `twitter.com/{user}/status/{id}`        | `permalink_url`                                         |
| **Primary Color**      | Sky blue (#0ea5e9)                      | Blue (#3b82f6)                                          |
| **Brand Icon**         | Twitter bird                            | Facebook f                                              |

**Critical Insight**: Twitter's `views_count` is **real data from the API**, making it more accurate than Facebook's estimated formula. This is a significant advantage for measuring actual reach and engagement.

### Future Enhancements

#### Potential Features

1. **Sentiment Analysis**:

   - Integrate with existing OpenAI sentiment analysis
   - Show positive/negative/neutral breakdown
   - Color-code tweets by sentiment in cards

2. **Comparative Analytics**:

   - Compare multiple topics side-by-side
   - Track topic growth over time
   - Benchmark against historical averages

3. **Real-Time Updates**:

   - WebSocket integration for live tweet streaming
   - Auto-refresh dashboards every N minutes
   - Notification badges for new high-engagement tweets

4. **Advanced Filtering**:

   - Filter by specific profiles
   - Filter by engagement threshold
   - Filter by verified accounts only
   - Filter by tweet type (original vs retweet vs quote)

5. **Export Options**:

   - CSV export of raw data
   - Excel export with charts
   - JSON API endpoints for external tools

6. **Engagement Prediction**:
   - ML model to predict tweet performance
   - Optimal posting time recommendations
   - Content pattern analysis

#### Technical Debt

1. **Caching Layer**: Implement fragment caching for expensive calculations
2. **Background Jobs**: Move word analysis to Sidekiq for large datasets
3. **Database Optimization**: Add composite indexes for common query patterns
4. **Test Coverage**: Write comprehensive RSpec tests for controller and model
5. **API Rate Limiting**: Handle Twitter API limits gracefully with queuing

### Dependencies & Requirements

**Ruby Gems**:

- `acts-as-taggable-on` - Tagging system
- `groupdate` - Date aggregation for charts
- `chartkick` - Chart abstraction layer
- `grover` - PDF generation

**JavaScript Libraries**:

- jQuery 3.7.1 - DataTables dependency
- DataTables 1.13.6 - Table functionality
- Highcharts 10.3.2 - Chart rendering

**External Services**:

- Twitter GraphQL API - Real-time tweet data
- Elasticsearch - Full-text search (optional)

**Environment Variables**:

- `TWITTER_AUTH_TOKEN` - Authentication token
- `TWITTER_CT0_TOKEN` - CSRF token
- `DAYS_RANGE` - Default date range (default: 7)

### Maintenance Notes

**Regular Tasks**:

1. Monitor Twitter API rate limits and adjust crawling frequency
2. Update stop words list as Spanish language evolves
3. Refresh topic tags periodically for relevance
4. Archive old tweets to maintain query performance
5. Update Twitter authentication tokens when they expire (30-90 days)

**Monitoring**:

- Track query execution times for optimization opportunities
- Monitor PDF generation failures (Grover crashes)
- Check DataTables performance with large datasets (>10k tweets)
- Validate chart rendering across browsers

**Known Issues**:

- Twitter API may return cached data (use authenticated API for fresh data)
- Payload format varies between development (Hash) and production (String)
- Views count may be 0 for very recent tweets (API delay)
- Word analysis skips tweets with non-ASCII characters (Spanish accents handled)

This comprehensive Twitter analytics implementation provides feature parity with the existing Facebook analytics while leveraging Twitter's unique engagement model and real-time API data for accurate insights into social media performance.

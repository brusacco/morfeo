# Morfeo - News Monitoring & Analytics Platform

Morfeo is a Rails 7 news monitoring system that crawls websites, extracts articles, performs sentiment analysis, and generates reports. It's essentially a media intelligence platform for Spanish-language news sources.

## Core Architecture

### Domain Models

- **Entry**: News articles with URL, title, content, sentiment polarity, and social media interaction counts
  - Social metrics: `reaction_count`, `comment_count`, `share_count`, `total_count`
  - Sentiment: `polarity` enum (0: neutral, 1: positive, 2: negative)
  - Content filtering: `repeated` status, `enabled` flag, `category` classification
  - Unique constraint on `url`, belongs to `site`
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

### Key Data Flow

1. **Crawling**: Anemone-based web crawler (`lib/tasks/crawler.rake`) visits sites hourly
2. **Extraction**: Services in `app/services/web_extractor_services/` parse content, dates, tags
3. **Analysis**: OpenAI integration for sentiment analysis and report generation
4. **Social Data**: Facebook Graph API integration for engagement metrics

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
- `WebExtractorServices::*` - Content parsing and tag extraction

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
rake facebook:fanpage_crawler # Social media data collection
```

### Search & Analytics

- **Elasticsearch**: Uses Searchkick gem for full-text search on entries
- **Charts**: Chartkick + Chart.js for analytics dashboards
- **Admin**: ActiveAdmin interface for content management

## Project-Specific Conventions

### Database

- Uses both SQLite3 (development) and MySQL2 (production)
- **Entry-centric design**: Core model with social metrics fields (`reaction_count`, `comment_count`, `share_count`, `total_count`)
- **Flexible tagging**: `acts-as-taggable-on` with dual contexts (`:tags`, `:title_tags`) via polymorphic `taggings` table
- **Daily analytics**: Dedicated tables (`topic_stat_dailies`, `title_topic_stat_dailies`) for trend analysis
- **User management**: Separate `users` (frontend) and `admin_users` (ActiveAdmin) with different access levels
- **Content versioning**: PaperTrail integration via `versions` table for audit trails
- **Facebook integration**: `pages` table stores fanpage metadata, `comments` stores social interactions
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
- **Elasticsearch**: Full-text search with Spanish-language considerations

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

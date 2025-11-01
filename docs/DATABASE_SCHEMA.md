# Morfeo Database Schema Documentation
**Last Updated**: November 1, 2025

## 📊 Database Overview

Morfeo uses MySQL 8.0 with a comprehensive schema designed for multi-channel media monitoring across Digital Media, Facebook, and Twitter.

---

## 🎯 Core Entity-Relationship Diagram

```
┌─────────────────────────────────────────────────────────────────┐
│                     MORFEO DATA MODEL                            │
└─────────────────────────────────────────────────────────────────┘

                         ┌──────────┐
                         │  Topic   │ (Central hub)
                         │          │
                         │ - name   │
                         │ - status │
                         └────┬─────┘
                              │
                    ┌─────────┴──────────┐
                    │                    │
              has_and_belongs_to_many  has_many
                    │                    │
                    ▼                    ▼
              ┌─────────┐         ┌──────────────┐
              │   Tag   │         │ User (via    │
              │         │         │ UserTopic)   │
              │ - name  │         │              │
              │ - variations      └──────────────┘
              └────┬────┘
                   │
         ┌─────────┼─────────┐ acts_as_taggable_on
         │         │         │
         ▼         ▼         ▼
    ┌────────┐ ┌──────────────┐ ┌─────────────┐
    │ Entry  │ │FacebookEntry │ │ TwitterPost │
    │(Digital)│ │  (Facebook)  │ │  (Twitter)  │
    └───┬────┘ └─────┬────────┘ └──────┬──────┘
        │            │                  │
        │            │                  │
    belongs_to   belongs_to        belongs_to
        │            │                  │
        ▼            ▼                  ▼
    ┌────────┐  ┌────────┐      ┌───────────────┐
    │  Site  │  │  Page  │      │TwitterProfile │
    │        │  │        │      │               │
    │ - name │  │ - uid  │      │ - uid         │
    │ - url  │  │ - name │      │ - username    │
    └────────┘  └───┬────┘      └───────┬───────┘
                    │                   │
                    └────────┬──────────┘
                             │ belongs_to (optional)
                             ▼
                        ┌────────┐
                        │  Site  │
                        └────────┘
```

---

## 📋 Table Catalog

### Content Tables (16)
- `entries` - Digital media articles
- `facebook_entries` - Facebook posts
- `twitter_posts` - Tweets
- `sites` - Media sources
- `pages` - Facebook pages
- `twitter_profiles` - Twitter accounts
- `topics` - Monitoring topics
- `tags` - Content tags
- `taggings` - Tag associations (acts_as_taggable_on)
- `comments` - Facebook comments (legacy)
- `newspapers` - Print editions
- `newspaper_texts` - Print content

### Access Control (3)
- `users` - Client users
- `admin_users` - Administrators
- `user_topics` - User-topic permissions

### Analytics & Reporting (4)
- `topic_stat_dailies` - Daily statistics
- `title_topic_stat_dailies` - Title-based stats
- `reports` - AI-generated reports
- `templates` - Report templates

### System Tables (6)
- `active_admin_comments` - Admin interface comments
- `active_storage_*` - File attachments (3 tables)
- `versions` - Audit trail (PaperTrail)
- `tags_topics` - Join table

**Total: 29 tables**

---

## 🔑 Primary Key Relationships

### Topics & Tags (Many-to-Many)
```sql
topics (id) ←→ tags_topics (tag_id, topic_id) ←→ tags (id)
```

### User Access Control (Many-to-Many)
```sql
users (id) ←→ user_topics (user_id, topic_id) ←→ topics (id)
```

### Digital Media (One-to-Many)
```sql
sites (id) ←→ entries (site_id)
```

### Facebook (One-to-Many)
```sql
sites (id) ←→ pages (site_id) ←→ facebook_entries (page_id)
```

### Twitter (One-to-Many)
```sql
sites (id) ←→ twitter_profiles (site_id) ←→ twitter_posts (twitter_profile_id)
```

### Cross-Channel Linking (Optional)
```sql
entries (id) ←→ facebook_entries (entry_id) [optional]
entries (id) ←→ twitter_posts (entry_id) [optional]
```

---

## 🏗️ Table Schemas

### `topics`
```sql
CREATE TABLE topics (
  id BIGINT PRIMARY KEY AUTO_INCREMENT,
  name VARCHAR(255) NOT NULL,
  positive_words TEXT,
  negative_words TEXT,
  status BOOLEAN DEFAULT TRUE,
  created_at DATETIME NOT NULL,
  updated_at DATETIME NOT NULL,
  INDEX(name),
  INDEX(status)
);
```

### `tags`
```sql
CREATE TABLE tags (
  id BIGINT PRIMARY KEY AUTO_INCREMENT,
  name VARCHAR(255) NOT NULL COLLATE utf8mb3_bin,
  variations VARCHAR(255),
  taggings_count INT DEFAULT 0,
  created_at DATETIME NOT NULL,
  updated_at DATETIME NOT NULL
);
```

### `entries` (Digital Media)
```sql
CREATE TABLE entries (
  id BIGINT PRIMARY KEY AUTO_INCREMENT,
  site_id INT NOT NULL,
  url VARCHAR(255) UNIQUE NOT NULL,
  title VARCHAR(255),
  description TEXT,
  content TEXT,
  published_at TIMESTAMP,
  published_date DATE,
  image_url TEXT,
  -- Engagement metrics (from Facebook on article URL)
  reaction_count INT DEFAULT 0,
  comment_count INT DEFAULT 0,
  share_count INT DEFAULT 0,
  comment_plugin_count INT DEFAULT 0,
  total_count INT DEFAULT 0,  -- Sum of all engagement
  -- Sentiment
  polarity INT,  -- enum: 0=neutral, 1=positive, 2=negative
  -- Meta
  enabled BOOLEAN DEFAULT TRUE,
  repeated INT DEFAULT 0,
  uid VARCHAR(255),
  category VARCHAR(255),
  delta INT DEFAULT 0,
  created_at DATETIME NOT NULL,
  updated_at DATETIME NOT NULL,
  INDEX(site_id),
  INDEX(url),
  INDEX(published_at),
  INDEX(published_date),
  INDEX(total_count),
  INDEX(polarity),
  INDEX(enabled, published_at)
);
```

### `facebook_entries`
```sql
CREATE TABLE facebook_entries (
  id BIGINT PRIMARY KEY AUTO_INCREMENT,
  page_id BIGINT NOT NULL,
  facebook_post_id VARCHAR(255) UNIQUE NOT NULL,
  posted_at DATETIME NOT NULL,
  fetched_at DATETIME,
  message TEXT,
  permalink_url VARCHAR(255),
  -- Attachment fields
  attachment_type VARCHAR(255),
  attachment_title TEXT,
  attachment_description TEXT,
  attachment_url VARCHAR(255),
  attachment_target_url VARCHAR(255),  -- External link (news article)
  attachment_media_src TEXT,
  attachment_media_width INT,
  attachment_media_height INT,
  attachments_raw JSON,
  -- Engagement metrics
  reactions_like_count INT DEFAULT 0,
  reactions_love_count INT DEFAULT 0,
  reactions_wow_count INT DEFAULT 0,
  reactions_haha_count INT DEFAULT 0,
  reactions_sad_count INT DEFAULT 0,
  reactions_angry_count INT DEFAULT 0,
  reactions_thankful_count INT DEFAULT 0,
  reactions_total_count INT DEFAULT 0,
  comments_count INT DEFAULT 0,
  share_count INT DEFAULT 0,
  views_count INT DEFAULT 0,  -- ACTUAL from Meta API
  -- Sentiment analysis
  sentiment_score DECIMAL(5,2),
  sentiment_label INT DEFAULT 0,  -- enum: 0-4
  sentiment_positive_pct DECIMAL(5,2),
  sentiment_negative_pct DECIMAL(5,2),
  sentiment_neutral_pct DECIMAL(5,2),
  controversy_index DECIMAL(5,4),
  emotional_intensity DECIMAL(8,4),
  -- Cross-channel linking
  entry_id BIGINT,
  payload JSON,
  created_at DATETIME NOT NULL,
  updated_at DATETIME NOT NULL,
  INDEX(page_id),
  INDEX(page_id, posted_at),
  INDEX(facebook_post_id),
  INDEX(entry_id),
  INDEX(sentiment_label),
  INDEX(sentiment_score),
  INDEX(sentiment_label, sentiment_score),
  INDEX(posted_at, sentiment_score),
  INDEX(controversy_index, sentiment_score),
  INDEX(emotional_intensity, posted_at),
  FOREIGN KEY(page_id) REFERENCES pages(id),
  FOREIGN KEY(entry_id) REFERENCES entries(id)
);
```

### `twitter_posts`
```sql
CREATE TABLE twitter_posts (
  id BIGINT PRIMARY KEY AUTO_INCREMENT,
  twitter_profile_id BIGINT NOT NULL,
  tweet_id VARCHAR(255) UNIQUE NOT NULL,
  posted_at DATETIME NOT NULL,
  fetched_at DATETIME,
  text TEXT,
  permalink_url VARCHAR(255),
  -- Engagement metrics
  quote_count INT DEFAULT 0,
  reply_count INT DEFAULT 0,
  retweet_count INT DEFAULT 0,
  favorite_count INT DEFAULT 0,
  views_count INT DEFAULT 0,  -- ACTUAL from Twitter API (when available)
  bookmark_count INT DEFAULT 0,
  -- Metadata
  lang VARCHAR(255),
  source VARCHAR(255),
  is_retweet BOOLEAN DEFAULT FALSE,
  is_quote BOOLEAN DEFAULT FALSE,
  -- Cross-channel linking
  entry_id BIGINT,
  payload JSON,
  created_at DATETIME NOT NULL,
  updated_at DATETIME NOT NULL,
  INDEX(twitter_profile_id),
  INDEX(twitter_profile_id, posted_at),
  INDEX(tweet_id),
  INDEX(entry_id),
  FOREIGN KEY(twitter_profile_id) REFERENCES twitter_profiles(id),
  FOREIGN KEY(entry_id) REFERENCES entries(id)
);
```

### `sites`
```sql
CREATE TABLE sites (
  id BIGINT PRIMARY KEY AUTO_INCREMENT,
  name VARCHAR(255) UNIQUE NOT NULL,
  url VARCHAR(255) UNIQUE NOT NULL,
  filter VARCHAR(255),              -- CSS selector for content
  content_filter VARCHAR(255),      -- Additional selectors
  negative_filter VARCHAR(255),     -- Selectors to exclude
  status BOOLEAN DEFAULT TRUE,
  is_js BOOLEAN DEFAULT FALSE,      -- Requires JavaScript rendering
  entries_count INT DEFAULT 0,      -- Counter cache
  image64 TEXT,                     -- Base64 logo
  -- Aggregate metrics (legacy)
  reaction_count INT DEFAULT 0,
  comment_count INT DEFAULT 0,
  share_count INT DEFAULT 0,
  comment_plugin_count INT DEFAULT 0,
  total_count INT DEFAULT 0,
  created_at DATETIME NOT NULL,
  updated_at DATETIME NOT NULL,
  INDEX(name),
  INDEX(url)
);
```

### `pages` (Facebook)
```sql
CREATE TABLE pages (
  id BIGINT PRIMARY KEY AUTO_INCREMENT,
  site_id INT,
  uid VARCHAR(255) NOT NULL,     -- Facebook page ID
  name VARCHAR(255),
  username VARCHAR(255),
  picture TEXT,
  followers INT DEFAULT 0,
  category VARCHAR(255),
  description TEXT,
  website VARCHAR(255),
  created_at DATETIME NOT NULL,
  updated_at DATETIME NOT NULL,
  INDEX(site_id)
);
```

### `twitter_profiles`
```sql
CREATE TABLE twitter_profiles (
  id BIGINT PRIMARY KEY AUTO_INCREMENT,
  site_id BIGINT,
  uid VARCHAR(255) UNIQUE NOT NULL,  -- Twitter user ID
  name VARCHAR(255),                 -- Display name
  username VARCHAR(255),             -- @handle
  picture TEXT,
  followers INT DEFAULT 0,
  description TEXT,
  verified BOOLEAN DEFAULT FALSE,
  created_at DATETIME NOT NULL,
  updated_at DATETIME NOT NULL,
  INDEX(site_id),
  INDEX(uid)
);
```

### `users`
```sql
CREATE TABLE users (
  id BIGINT PRIMARY KEY AUTO_INCREMENT,
  name VARCHAR(255),
  email VARCHAR(255) UNIQUE NOT NULL,
  encrypted_password VARCHAR(255) NOT NULL,
  reset_password_token VARCHAR(255) UNIQUE,
  reset_password_sent_at DATETIME,
  remember_created_at DATETIME,
  status BOOLEAN DEFAULT TRUE,
  created_at DATETIME NOT NULL,
  updated_at DATETIME NOT NULL,
  INDEX(email),
  INDEX(name),
  INDEX(reset_password_token)
);
```

### `user_topics` (Join table)
```sql
CREATE TABLE user_topics (
  id BIGINT PRIMARY KEY AUTO_INCREMENT,
  user_id BIGINT NOT NULL,
  topic_id BIGINT NOT NULL,
  created_at DATETIME NOT NULL,
  updated_at DATETIME NOT NULL,
  INDEX(user_id),
  INDEX(topic_id),
  FOREIGN KEY(user_id) REFERENCES users(id),
  FOREIGN KEY(topic_id) REFERENCES topics(id)
);
```

---

## 🔍 Critical Indexes

### Performance-Critical Indexes

#### Date Range Queries (Most Common)
```sql
-- entries
INDEX(published_at)
INDEX(published_date)
INDEX(enabled, published_at)

-- facebook_entries
INDEX(posted_at, sentiment_score)
INDEX(page_id, posted_at)

-- twitter_posts
INDEX(posted_at)
INDEX(twitter_profile_id, posted_at)
```

#### Tag-Based Queries (acts_as_taggable_on)
```sql
-- taggings
INDEX(taggable_type, taggable_id)
INDEX(tag_id, taggable_type)
INDEX(taggable_id, taggable_type, context)
```

#### Engagement Metrics
```sql
-- entries
INDEX(total_count)

-- facebook_entries
INDEX(sentiment_label, sentiment_score)
INDEX(controversy_index, sentiment_score)
```

---

## 📊 Key Constraints & Validations

### Unique Constraints
```sql
entries.url               -- No duplicate articles
facebook_entries.facebook_post_id  -- No duplicate posts
twitter_posts.tweet_id    -- No duplicate tweets
pages.uid                 -- No duplicate FB pages
twitter_profiles.uid      -- No duplicate Twitter profiles
sites.name                -- No duplicate sites
sites.url                 -- No duplicate site URLs
users.email               -- No duplicate user emails
```

### Foreign Key Constraints
```sql
facebook_entries.page_id → pages.id
facebook_entries.entry_id → entries.id (optional)
twitter_posts.twitter_profile_id → twitter_profiles.id
twitter_posts.entry_id → entries.id (optional)
entries.site_id → sites.id
pages.site_id → sites.id
twitter_profiles.site_id → sites.id
user_topics.user_id → users.id
user_topics.topic_id → topics.id
```

---

## 🎯 Data Flow & Aggregation

### 1. Content Ingestion Flow

#### Digital Media (Web Scraping)
```
Sidekiq Job → Scraper Service
  ↓
Parse HTML (Nokogiri)
  ↓
Create/Update Entry (site_id, url, title, content, etc.)
  ↓
Fetch Facebook engagement (Graph API)
  ↓
Update Entry (reaction_count, comment_count, share_count, total_count)
  ↓
AI Sentiment Analysis (OpenAI)
  ↓
Update Entry (polarity: neutral/positive/negative)
  ↓
Auto-tag (Searchkick + acts_as_taggable_on)
```

#### Facebook (Meta API)
```
Sidekiq Job → Facebook Service
  ↓
Fetch posts from Page (Graph API)
  ↓
Create/Update FacebookEntry (page_id, message, reactions, etc.)
  ↓
Calculate sentiment_score (weighted reactions)
  ↓
Auto-calculate sentiment_label, controversy_index, emotional_intensity
  ↓
Auto-tag (acts_as_taggable_on)
  ↓
Try to link to Entry (via attachment_target_url)
```

#### Twitter (Twitter API v2)
```
Sidekiq Job → Twitter Service
  ↓
Fetch tweets from Profile (Twitter API)
  ↓
Create/Update TwitterPost (twitter_profile_id, text, favorite_count, views_count, etc.)
  ↓
Auto-tag (acts_as_taggable_on)
  ↓
Try to link to Entry (via external_urls)
```

### 2. Dashboard Aggregation Flow

```
User Request → Controller
  ↓
Get Topic (with tags)
  ↓
Call AggregatorService.call(topic, start_date, end_date)
  ↓
┌─────────────────────────────────────────┐
│  Parallel Data Fetching (Cached 30min)  │
├─────────────────────────────────────────┤
│ 1. digital_data:                        │
│    Entry.where(published_at: range)     │
│         .tagged_with(tags, any: true)   │
│         .sum(:total_count)              │
│                                         │
│ 2. facebook_data:                       │
│    FacebookEntry.where(posted_at: range)│
│                .tagged_with(tags)       │
│                .sum(:views_count)       │
│                                         │
│ 3. twitter_data:                        │
│    TwitterPost.where(posted_at: range)  │
│              .tagged_with(tags)         │
│              .sum(:views_count)         │
└─────────────────────────────────────────┘
  ↓
Aggregate & Calculate Metrics
  ↓
Return Hash (executive_summary, channel_performance, sentiment, etc.)
  ↓
Render View (show.html.erb)
```

---

## 🚀 Performance Optimization

### Query Patterns

#### ✅ Efficient Tag Queries
```ruby
# ALWAYS use distinct count with acts_as_taggable_on
FacebookEntry.tagged_with(tags, any: true)
             .count('DISTINCT facebook_entries.id')
```

#### ✅ Avoid N+1 with Eager Loading
```ruby
# ALWAYS include associations
Entry.includes(:site).where(...)
FacebookEntry.includes(:page).where(...)
TwitterPost.includes(:twitter_profile).where(...)
```

#### ✅ Use Scopes for Common Patterns
```ruby
Entry.enabled.normal_range.has_interactions
FacebookEntry.for_topic(topic, start_time:, end_time:)
TwitterPost.for_topic(topic, start_time:, end_time:)
```

### Caching Strategy
```ruby
# Topic queries: 30 minutes
Rails.cache.fetch("topic_#{id}_list_entries", expires_in: 30.minutes)

# Temporal intelligence: 2 hours
Rails.cache.fetch("topic_#{id}_peak_times_hour", expires_in: 2.hours)

# Sentiment analysis: 2 hours
Rails.cache.fetch("topic_#{id}_fb_sentiment_v2_#{date}", expires_in: 2.hours)

# General Dashboard: 30 minutes
Rails.cache.fetch("general_dashboard_#{topic.id}_#{date}", expires_in: 30.minutes)
```

---

## 📚 Additional Resources

- **Schema File**: `/db/schema.rb`
- **Migrations**: `/db/migrate/`
- **Model Files**: `/app/models/`
- **Cursor Rules**: `/.cursorrules`
- **Validation Report**: `/docs/COMPLETE_VALIDATION_SUMMARY.md`

---

**Generated by**: Morfeo Schema Documentation Generator  
**Database Version**: MySQL 8.0  
**Rails Version**: 7.0.8  
**Ruby Version**: 3.1.6


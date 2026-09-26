# Change Log

## 2026-09-26

- Removed the inapplicable `reach: 0` key from unavailable Instagram Home
  channel data and versioned the Home dashboard cache payload from v9 to v10.
- Renamed the General PDF total-reach KPI to `Alcance potencial total` so its
  label does not imply that separately displayed Instagram video views are
  included.
- Marked the Instagram channel engagement rate unavailable in General and Home:
  all-content interactions cannot be divided by video-only observed views.
  Versioned both cached payloads from v8 to v9.
- Aligned General and Home cross-channel engagement rates with their reach
  denominator: displayed interactions still include Instagram, while the rate
  uses only Digital, Facebook, and X interactions. Versioned both cached payloads
  from v7 to v8.
- Consolidated the verified read-only Facebook, X, and Instagram production
  statistics into a cross-channel calibration reference, including datasets,
  distributions, model errors, data-quality findings, and reuse limitations.
- Corrected Instagram dashboard semantics: provider `video_view_count` is now
  exposed as observed views or `N/D`, never as reach and never through an
  interaction-based fallback. General and Home exclude Instagram views from
  reach totals and reach charts.
- Recorded the read-only X calibration: approximately 97.82% positive observed
  view coverage, no sufficiently superior simple fallback, and the existing
  zero-versus-unavailable provenance limitation.
- Recorded the read-only production analysis of Instagram metrics: provider video
  views cover applicable videos but not non-video posts; no simple fallback is
  sufficiently defensible; video views are not unique reach. Documented the
  current General/Home semantic limitation that maps those views to a reach key.
- Recorded the read-only production calibration of Facebook reach estimation:
  564,456 posts, v1/v2 bounded-formula evidence, parameter sensitivity, and the
  absence of observed Facebook reach ground truth. Documented that page followers
  are mutable `fan_count` values rather than per-post historical snapshots.
- Added Instagram as the fourth Home Dashboard channel across executive totals,
  channel comparisons, charts, temporal engagement, and Top Content. Versioned
  its payload cache from `home_dashboard:v4` to `home_dashboard:v5`.
- Added Instagram as the fourth channel in the General Dashboard: its tagged,
  range-scoped posts now contribute to mentions, interactions, observed video-view
  reach, competitive totals, temporal aggregates, top content, viral content,
  charts, and the General Dashboard PDF.
- Versioned the General Dashboard snapshot key from `general_dashboard:v4` to
  `general_dashboard:v5`. The cache now stores only stable top-content metadata
  and attaches all relational content after the cache read, avoiding redundant
  cache-miss construction.
- Kept Instagram out of weighted global sentiment and distribution calculations
  because no equivalent sentiment source is implemented.
- Restored the General Dashboard combined text-analysis hash after a misplaced
  Instagram relation caused recommendation generation to index an Active Record
  relation with a symbol. Added a regression spec for the hash contract.
- Added the missing Instagram column to the General Dashboard Top Content
  preview, matching the existing four-channel PDF coverage.

## 2026-09-25

- Added Rails `race_condition_ttl` protection to all dashboard aggregator caches and Digital's costly subcaches to prevent cache stampedes after Redis expiration.
- Preserved Active Record relations for topic tag filters, Home dashboard statistics, tag authorization, and Facebook emotional-intensity aggregates to avoid intermediate ID arrays.
- Moved Home Tags Cloud analysis into the versioned Home dashboard payload and introduced `home_dashboard:v4` to prevent old cached hashes from omitting the new field.
- Extended `cache:warm_dashboards` to warm each distinct user-specific Home topic set after per-topic dashboards.
- Fixed General Dashboard tagged Facebook aggregates for MariaDB/MySQL by counting explicit Facebook entry IDs in trend velocity and sentiment intensity; this avoids invalid `COUNT(facebook_entries.*)` SQL while preserving any-tag semantics.
- Preserved the first dashboard failure on each `cache:warm_dashboards` topic result so the task summary reports its exception instead of blank error fields.

## 2026-09-22

- Documented all background jobs: ActiveJob architecture, core jobs, tags jobs, error handling patterns
- Documented all services: service object architecture, dashboard aggregators, PDF services, web extractors, crawlers, social media services, AI services
- Documented all controllers: architecture, authorization concerns, caching strategy, and error handling patterns
- Added Development Guidelines as the durable Rails workflow and documentation-ownership reference
- Corrected PDF documentation: Instagram uses its dashboard aggregator, and the general-dashboard PDF route is plural
- Reduced `copilot-instructions.md` to concise project guardrails with links to the OKF bundle

## 2026-09-22

- Created OKF bundle documenting all 22 domain models
- Documented core content models: Entry, Site, Topic, Tag
- Documented social media models: FacebookEntry, TwitterPost, TwitterProfile, Page, InstagramPost, InstagramProfile
- Documented analytics models: TopicStatDaily, TitleTopicStatDaily, Comment
- Documented user/auth models: User, AdminUser
- Documented join models: EntryTopic, EntryTitleTopic, UserTopic
- Documented supporting models: Report, Template, Newspaper, NewspaperText, Version, RecentEntry

## 2026-09-22

- Created Facebook Reports infrastructure documentation
- Documented FacebookTopicController with show, entries_data, pdf actions
- Documented Facebook topic views and PDF templates
- Documented AggregatorService data structure and interface
- Documented PDF generation service
- Documented Facebook API integration services

## 2026-09-22

- Created Twitter Reports infrastructure documentation
- Documented TwitterTopicController with show, entries_data, pdf actions
- Documented Twitter topic views and PDF templates
- Documented AggregatorService data structure and interface
- Documented PDF generation service
- Documented Twitter API integration services (authenticated vs guest token)

## 2026-09-22

- Created Instagram Reports infrastructure documentation
- Documented InstagramTopicController with show, entries_data, pdf actions
- Documented Instagram topic views and PDF templates
- Documented AggregatorService data structure and interface
- Documented Instagram API integration services

## 2026-09-22

- Created Digital Media Reports infrastructure documentation
- Documented TopicController with show, pdf, comments, history, entries_data actions
- Documented digital topic views and PDF templates
- Documented AggregatorService data structure and interface
- Documented PDF generation service
- Added cross-links between all report infrastructure sections

## 2026-09-22

- Created Business Rules documentation section
- Documented 11 high-level business rules:
  - Content Crawling
  - Topic Organization
  - Tag Inheritance
  - Social Media Integration
  - URL Matching
  - Engagement Metrics
  - Sentiment Analysis
  - Views Estimation
  - Reporting
  - User Access Control
- Added cross-links from models and reports to business rules

## 2026-09-22

- Created Caching Strategy documentation
- Documented multi-layer caching architecture:
  - Redis cache store configuration
  - Action caching for controllers
  - Service-level caching for dashboard aggregators
  - PDF caching with PdfCacheable concern
  - Cache warming via scheduled rake tasks
  - Cache invalidation strategies

## 2026-09-22

- Created Aggregator Services documentation
- Documented 6 aggregator services:
  - Digital Dashboard Aggregator
  - Facebook Dashboard Aggregator
  - Twitter Dashboard Aggregator
  - Instagram Dashboard Aggregator
  - General Dashboard Aggregator (CEO-level reporting)
  - Site Dashboard Aggregator
- Documented performance optimizations: caching, memoization, query optimization, batch processing

## 2026-09-22

- Created PDF Report Generation documentation
- Documented PDF generation architecture using Grover and Chrome headless
- Documented 6 PDF report types:
  - Digital Media PDF
  - Facebook PDF
  - Twitter PDF
  - Instagram PDF
  - General Dashboard PDF (CEO-level)
  - Tag PDF
- Documented PDF service architecture and caching strategy
- Documented Grover configuration and performance optimizations

## 2026-09-22

- Created Twitter Account Management documentation
- Documented multi-account Twitter API authentication system
- Documented automatic rate limit rotation with up to 5 accounts
- Documented AccountManager service architecture and Redis cache keys
- Documented 4 rake tasks for account management
- Documented integration with Twitter data collection services
- Documented monitoring and best practices

## 2026-09-22

- Created Scheduled Tasks documentation
- Documented complete cron schedule from config/schedule.rb
- Documented all task frequencies: 5-min cache warming, hourly, 3-hour, 4-hour, 6-hour, daily, weekly
- Documented 20+ scheduled rake tasks with purposes and related concepts
- Documented task dependencies and ordering strategy
- Documented commented-out tasks available for manual scheduling

## 2026-09-22

- Created Crawler Infrastructure documentation
- Documented 7 crawler types:
  - Standard Web Crawler (Anemone)
  - Headless Crawler (Selenium/Chrome)
  - Proxy Crawler (scrape.do API)
  - Social Media Crawler (Twitter/Facebook URL extraction)
  - Facebook Fanpage Crawler (Graph API)
  - Twitter Profile Crawler (GraphQL API)
  - Instagram Posts Crawler (Graph API)
- Documented service architectures for each crawler type
- Documented performance optimizations and crawler selection logic

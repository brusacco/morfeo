# frozen_string_literal: true

set :environment, 'production'

# =============================================================================
# CACHE WARMING - Every 5 minutes
# =============================================================================
# Keeps dashboards fast by pre-loading data into Redis cache
# All caches expire after 30 minutes, ensuring fresh data
every 5.minutes do
  rake 'cache:warm_dashboards'
end

# =============================================================================
# HOURLY TASKS - Core data collection
# =============================================================================
# These tasks run every hour to collect and process data from various sources
every :hour do
  rake 'crawler'              # Crawl websites for new articles (depth: 2)
  rake 'proxy_crawler'        # JS-rendered sites via proxy
  # rake 'update_stats'         # Update Facebook stats for articles
  rake 'update_api'           # Update Facebook stats via API
  rake 'update_site_stats'    # Aggregate site-level statistics
  rake 'update_dates'         # Fix/standardize publication dates
  rake 'clean_site_content'   # Remove unwanted content/formatting
  rake 'category'             # Categorize entries
  rake 'topic_stat_daily'     # Generate daily statistics per topic
  rake 'title_topic_stat_daily' # Generate title-based stats
end

# =============================================================================
# EVERY 3 HOURS - Social media crawling
# =============================================================================
every 3.hours do
  rake 'facebook:fanpage_crawler[2]'   # Crawl Facebook pages (3 pages = ~300 posts per page)
  rake 'twitter:profile_crawler_full'  # Crawl Twitter profiles for new tweets
  rake 'social_crawler'                # General social media crawler
  # rake 'facebook:comment_crawler'    # Disabled: too heavy
end

# =============================================================================
# EVERY 4 HOURS - Content tagging
# =============================================================================
every 4.hours do
  rake 'repeated_notes' # Detect and mark duplicate articles
  rake 'instagram:posts_crawler' # Crawl Instagram posts
  # rake 'title_tagger' removed - tagger already handles both tags and title_tags
end

# =============================================================================
# EVERY 6 HOURS - Deep processing and AI
# =============================================================================
every 6.hours do
  rake 'ai:generate_ai_reports'    # Generate AI-powered topic reports
  rake 'ai:set_topic_polarity'     # Set sentiment/polarity for topics
  rake 'facebook:update_fanpages'  # Update Facebook page metadata
  rake 'tagger' # Re-tag entries from last 7 days (default)
  rake 'instagram:posts_crawler' # Crawl Instagram posts
end
# =============================================================================
# 🆕 DAILY at 3:00 AM - Deep re-tagging (NEW!)
# =============================================================================
# Comprehensive re-tagging of last 60 days
# Runs at 3am when server load is lowest
# NOTE: tagger already syncs entries to topics via sync_topics_from_tags
every 1.day, at: '3:00 am' do
  rake 'crawler[3]' # Deep crawl for missed content (depth: 3)
  rake 'tagger[60]' # Deep re-tag last 60 days (includes automatic sync)
end

# =============================================================================
# 🆕 WEEKLY - Full sync safety check (TEMPORARY - Remove after Jan 2026)
# =============================================================================
# ⚠️ TEMPORARY: Keep for 2-4 weeks after sync_topics_from_tags fix deployed
# This is a safety net while we verify the bug fix works correctly in production
# TODO: Remove after verifying daily tagger[60] is sufficient
# Weekly comprehensive sync as safety net to catch any missed entries
# Runs Sundays at 4am after the daily tagger completes
every :sunday, at: '4:00 am' do
  rake 'topic:sync_all[60]' # Weekly safety sync for all topics
end

# =============================================================================
# 🆕 WEEKLY - Update 60-day statistics for PDF reports
# =============================================================================
# Updates topic_stat_dailies for last 60 days to support all PDF report ranges
# Runs Sundays at 5am after the weekly sync completes
every :sunday, at: '5:00 am' do
  rake 'topic_stat_daily[60]'       # Update 60-day daily statistics for all topics
  rake 'title_topic_stat_daily[60]' # Update 60-day title-based statistics for all topics
end

# =============================================================================
# 🆕 DAILY at 6:00 AM - Health check (NEW!)
# =============================================================================
# Audits sync health and alerts if issues are detected
# Runs after sync completes, before business hours start
every 1.day, at: '6:00 am' do
  rake 'audit:sync_health' # Check for sync issues and log/alert
end

# =============================================================================
# COMMENTED OUT - Available but not currently scheduled
# =============================================================================
# These tasks are available but not actively scheduled
# Uncomment and adjust timing if needed
#
# every 12.hours do
#   rake 'twitter:link_to_entries'      # Link tweets to news articles
#   rake 'facebook:link_to_entries'     # Link FB posts to news articles
#   rake 'twitter:post_tagger'          # Tag Twitter posts
#   rake 'facebook:entry_tagger'        # Tag Facebook entries
# end

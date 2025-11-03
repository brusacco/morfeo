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
  rake 'crawler'              # Crawl websites for new articles
  rake 'proxy_crawler'        # JS-rendered sites via proxy
  rake 'update_stats'         # Update Facebook stats for articles
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
  rake 'facebook:fanpage_crawler'      # Crawl Facebook pages for new posts
  rake 'twitter:profile_crawler_full'  # Crawl Twitter profiles for new tweets
  rake 'social_crawler'                # General social media crawler
  # rake 'facebook:comment_crawler'    # Disabled: too heavy
end

# =============================================================================
# EVERY 4 HOURS - Content tagging
# =============================================================================
every 4.hours do
  rake 'repeated_notes'  # Detect and mark duplicate articles
  rake 'title_tagger'    # Tag entries based on title (last 7 days)
end

# =============================================================================
# EVERY 6 HOURS - Deep processing and AI
# =============================================================================
every 6.hours do
  rake 'crawler_deep'              # Deep crawl for missed content
  rake 'ai:generate_ai_reports'    # Generate AI-powered topic reports
  rake 'ai:set_topic_polarity'     # Set sentiment/polarity for topics
  rake 'facebook:update_fanpages'  # Update Facebook page metadata
end

# =============================================================================
# 🆕 EVERY 12 HOURS - Comprehensive re-tagging (NEW!)
# =============================================================================
# This ensures entries from the last 60 days are re-tagged with any new tags
# Runs at 2:00 AM and 2:00 PM to catch changes made during business hours
every 12.hours, at: ['2:00 am', '2:00 pm'] do
  rake 'tagger'  # Re-tag ALL entries from last 60 days
end

# =============================================================================
# 🆕 DAILY at 3:00 AM - Sync all topics (NEW!)
# =============================================================================
# This syncs the entry_topics association table for all topics
# Ensures PDF reports and association-based queries have correct data
# Runs after the 2:00 AM tagger task completes
every 1.day, at: '3:00 am' do
  rake 'topic:sync_all[60]'  # Sync entry_topics for all topics (60 days)
end

# =============================================================================
# 🆕 DAILY at 6:00 AM - Health check (NEW!)
# =============================================================================
# Audits sync health and alerts if issues are detected
# Runs after sync completes, before business hours start
every 1.day, at: '6:00 am' do
  rake 'audit:sync_health'  # Check for sync issues and log/alert
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

# frozen_string_literal: true

# Configuration constants for PDF generation
# This module centralizes all PDF-related constants to avoid magic numbers
module PdfConstants
  # Chart Configuration
  DEFAULT_CHART_HEIGHT = '200px'
  DEFAULT_LINE_WIDTH = 2
  DEFAULT_MARKER_RADIUS = 4
  
  # Chart Colors - Digital Media
  DIGITAL_PRIMARY_COLOR = '#1e3a8a'    # Dark blue
  DIGITAL_SUCCESS_COLOR = '#10b981'    # Green
  DIGITAL_WARNING_COLOR = '#f59e0b'    # Amber
  
  # Chart Colors - Facebook
  FACEBOOK_PRIMARY_COLOR = '#1877f2'   # Facebook blue
  FACEBOOK_LOVE_COLOR = '#f43f5e'      # Rose
  FACEBOOK_HAHA_COLOR = '#f59e0b'      # Amber
  FACEBOOK_WOW_COLOR = '#a855f7'       # Purple
  FACEBOOK_SAD_COLOR = '#3b82f6'       # Blue
  FACEBOOK_ANGRY_COLOR = '#ef4444'     # Red
  FACEBOOK_CARE_COLOR = '#10b981'      # Green
  
  # Chart Colors - Twitter
  TWITTER_PRIMARY_COLOR = '#1da1f2'    # Twitter blue
  TWITTER_LIKE_COLOR = '#e0245e'       # Red/Pink
  TWITTER_RETWEET_COLOR = '#17bf63'    # Green
  TWITTER_REPLY_COLOR = '#1da1f2'      # Blue
  
  # Chart Colors - Sentiment
  SENTIMENT_POSITIVE_COLOR = '#10b981' # Green
  SENTIMENT_NEUTRAL_COLOR = '#6b7280'  # Gray
  SENTIMENT_NEGATIVE_COLOR = '#ef4444' # Red
  
  # Chart Color Palettes
  DIGITAL_PIE_COLORS = ['#1e3a8a', '#F97316', '#10B981', '#F59E0B', '#EC4899'].freeze
  FACEBOOK_PIE_COLORS = ['#0284c7', '#6366F1', '#22C55E', '#D97706', '#EF4444'].freeze
  TWITTER_PIE_COLORS = ['#1da1f2', '#8B5CF6', '#EC4899', '#14B8A6', '#F59E0B'].freeze
  
  REACTION_COLORS = [
    '#1877f2', # Like
    '#f43f5e', # Love
    '#f59e0b', # Haha
    '#a855f7', # Wow
    '#3b82f6', # Sad
    '#10b981', # Care
    '#ec4899'  # Angry
  ].freeze
  
  # Sentiment Colors Array (for charts)
  SENTIMENT_COLORS = [
    SENTIMENT_POSITIVE_COLOR,
    SENTIMENT_NEUTRAL_COLOR,
    SENTIMENT_NEGATIVE_COLOR
  ].freeze
  
  # Data Display Limits
  MAX_TOP_POSTS = 15
  MAX_TOP_POSTS_PDF = 10
  MAX_SITES_DISPLAY = 12
  MAX_WORDS_DISPLAY = 50
  MAX_BIGRAMS_DISPLAY = 30
  MAX_TAGS_DISPLAY = 10
  
  # Reach Calculation
  DIGITAL_REACH_MULTIPLIER = 3     # Conservative estimate: 1 interaction ≈ 3 readers
  TWITTER_FALLBACK_MULTIPLIER = 10 # Fallback when views_count unavailable
  
  # Sentiment Thresholds (Facebook - reaction-based)
  FACEBOOK_SENTIMENT_VERY_POSITIVE = 1.5
  FACEBOOK_SENTIMENT_POSITIVE = 0.5
  FACEBOOK_SENTIMENT_NEUTRAL_MAX = 0.5
  FACEBOOK_SENTIMENT_NEUTRAL_MIN = -0.5
  FACEBOOK_SENTIMENT_NEGATIVE = -0.5
  FACEBOOK_SENTIMENT_VERY_NEGATIVE = -1.5
  
  # Sentiment Confidence Thresholds
  HIGH_CONFIDENCE_THRESHOLD = 0.7
  MODERATE_CONFIDENCE_THRESHOLD = 0.5
  LOW_CONFIDENCE_THRESHOLD = 0.3
  
  # Text Truncation
  POST_MESSAGE_TRUNCATE_LENGTH = 200
  TITLE_TRUNCATE_LENGTH = 100
  DESCRIPTION_TRUNCATE_LENGTH = 150
  
  # PDF Generation
  PDF_CACHE_DURATION = 30.minutes
  PDF_GENERATION_TIMEOUT = 60.seconds
  
  # Formatting
  NUMBER_DELIMITER = '.'
  PERCENTAGE_PRECISION = 1
  CURRENCY_PRECISION = 0
  
  # Date Ranges
  DEFAULT_DAYS_RANGE = 7
  MAX_DAYS_RANGE = 90
  MIN_DAYS_RANGE = 1
end


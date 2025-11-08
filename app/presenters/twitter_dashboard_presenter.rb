# frozen_string_literal: true

# Presenter for Twitter dashboard
# Encapsulates Twitter-specific dashboard logic and data formatting
#
# Unlike Facebook (which has sentiment), Twitter focuses on:
# - Engagement metrics (likes, retweets, replies, quotes)
# - Views data (when available from API)
# - Viral content detection
# - Profile and tag analytics
class TwitterDashboardPresenter
  attr_reader :total_posts, :total_interactions, :total_views, :average_interactions,
              :chart_posts, :chart_interactions, :tag_counts, :tag_interactions,
              :profiles_count, :profiles_interactions, :top_posts, :posts,
              :viral_content, :word_occurrences, :bigram_occurrences,
              :positive_words, :negative_words, :site_top_counts, :topic

  # Initialize presenter with Twitter dashboard data
  #
  # @param options [Hash] Dashboard data from TwitterDashboardServices
  # @option options [Topic] :topic The topic being displayed
  # @option options [Integer] :total_posts Total number of tweets
  # @option options [Integer] :total_interactions Sum of all interactions
  # @option options [Integer] :total_views Total tweet views
  # @option options [Float] :average_interactions Average per tweet
  # @option options [Hash] :chart_posts Time series data for tweets
  # @option options [Hash] :chart_interactions Time series data for interactions
  # @option options [Hash] :tag_counts Tag distribution by count
  # @option options [Hash] :tag_interactions Tag distribution by interactions
  # @option options [Hash] :profiles_count Profile distribution by count
  # @option options [Hash] :profiles_interactions Profile distribution by interactions
  # @option options [Array] :top_posts Top tweets by engagement
  # @option options [Array] :posts All tweets
  # @option options [Array] :viral_content Viral tweets
  # @option options [Hash] :word_occurrences Word frequency analysis
  # @option options [Hash] :bigram_occurrences Bigram frequency analysis
  # @option options [Array] :positive_words Positive keywords
  # @option options [Array] :negative_words Negative keywords
  # @option options [Hash] :site_top_counts Top sources
  def initialize(options = {})
    @topic = options[:topic]
    @total_posts = options[:total_posts] || 0
    @total_interactions = options[:total_interactions] || 0
    @total_views = options[:total_views] || 0
    @average_interactions = options[:average_interactions] || 0
    @chart_posts = options[:chart_posts] || {}
    @chart_interactions = options[:chart_interactions] || {}
    @tag_counts = options[:tag_counts] || []
    @tag_interactions = options[:tag_interactions] || {}
    @profiles_count = options[:profiles_count] || {}
    @profiles_interactions = options[:profiles_interactions] || {}
    @top_posts = options[:top_posts] || []
    @posts = options[:posts] || []
    @viral_content = options[:viral_content] || []
    @word_occurrences = options[:word_occurrences] || {}
    @bigram_occurrences = options[:bigram_occurrences] || {}
    @positive_words = options[:positive_words] || []
    @negative_words = options[:negative_words] || []
    @site_top_counts = options[:site_top_counts] || {}
  end

  # Check if data is available
  # @return [Boolean] True if any data exists
  def has_data?
    @total_posts&.positive? || @posts&.any?
  end

  # Check if viral content exists
  # @return [Boolean] True if viral tweets detected
  def has_viral_content?
    @viral_content&.any?
  end

  # Get viral content count
  # @return [Integer] Number of viral tweets
  def viral_count
    @viral_content&.size || 0
  end

  # Check if word cloud data exists
  # @return [Boolean] True if word occurrences present
  def has_word_cloud?
    @word_occurrences&.any?
  end

  # Check if bigram data exists
  # @return [Boolean] True if bigram occurrences present
  def has_bigram_data?
    @bigram_occurrences&.any?
  end

  # Check if top posts exist
  # @return [Boolean] True if top posts present
  def has_top_posts?
    @top_posts&.any?
  end

  # Check if all posts exist
  # @return [Boolean] True if posts present
  def has_posts?
    @posts&.any?
  end

  # Check if tag data exists
  # @return [Boolean] True if tag data present
  def has_tag_data?
    @tag_counts&.any? || @tag_interactions&.any?
  end

  # Check if profile data exists
  # @return [Boolean] True if profile data present
  def has_profile_data?
    @profiles_count&.any? || @profiles_interactions&.any?
  end

  # Check if chart data exists
  # @return [Boolean] True if chart data present
  def has_chart_data?
    @chart_posts&.any? || @chart_interactions&.any?
  end

  # Get formatted total posts with delimiter
  # @return [String] Formatted number
  def formatted_total_posts
    format_number(@total_posts)
  end

  # Get formatted total interactions with delimiter
  # @return [String] Formatted number
  def formatted_total_interactions
    format_number(@total_interactions)
  end

  # Get formatted total views with delimiter
  # @return [String] Formatted number
  def formatted_total_views
    format_number(@total_views)
  end

  # Get formatted average interactions with delimiter
  # @return [String] Formatted number
  def formatted_average_interactions
    format_number(@average_interactions)
  end

  # Get engagement rate
  # @return [Float] Engagement rate percentage
  def engagement_rate
    return 0.0 if @total_views.zero?
    ((@total_interactions.to_f / @total_views) * 100).round(2)
  end

  # Check if views data is available
  # @return [Boolean] True if views > 0
  def has_views_data?
    @total_views&.positive?
  end

  # Get KPI cards data for rendering
  # @return [Array<Hash>] Array of KPI card configurations
  def kpi_cards
    [
      {
        title: I18n.t('twitter.kpis.tweets'),
        value: formatted_total_posts,
        icon: 'fa-brands fa-twitter',
        color: 'gray',
        hover_color: 'sky',
        description: I18n.t('twitter.kpis.tweets_description', days: days_range)
      },
      {
        title: I18n.t('twitter.kpis.interactions'),
        value: formatted_total_interactions,
        icon: 'fa-solid fa-chart-line',
        color: 'sky',
        hover_color: 'sky',
        description: I18n.t('twitter.kpis.interactions_description')
      },
      {
        title: I18n.t('twitter.kpis.views'),
        value: formatted_total_views,
        icon: 'fa-solid fa-eye',
        color: 'purple',
        hover_color: 'purple',
        description: I18n.t('twitter.kpis.views_description')
      },
      {
        title: I18n.t('twitter.kpis.average'),
        value: formatted_average_interactions,
        icon: 'fa-solid fa-calculator',
        color: 'green',
        hover_color: 'green',
        description: I18n.t('twitter.kpis.average_description')
      }
    ]
  end

  # Get chart configurations
  # @return [Hash] Chart configuration data
  def chart_configs
    {
      posts: {
        data: @chart_posts,
        chart_id: 'twitterPostsChart',
        label: I18n.t('twitter.charts.tweets'),
        color: :sky,
        title: I18n.t('twitter.charts.tweets_per_day'),
        xtitle: I18n.t('twitter.charts.date'),
        ytitle: I18n.t('twitter.charts.tweets')
      },
      interactions: {
        data: @chart_interactions,
        chart_id: 'twitterInteractionsChart',
        label: I18n.t('twitter.charts.interactions'),
        color: :success,
        title: I18n.t('twitter.charts.interactions_per_day'),
        xtitle: I18n.t('twitter.charts.date'),
        ytitle: I18n.t('twitter.charts.interactions')
      }
    }
  end

  # Get tag chart data formatted for pie charts
  # @return [Hash] Tag counts chart data
  def tag_counts_chart_data
    return {} unless @tag_counts.respond_to?(:map)
    @tag_counts.map { |tag| [tag.name, tag.count] }.to_h
  end

  # Configuration for presentational elements
  # @return [Hash] Configuration hash
  def config
    {
      days_range: days_range,
      colors: {
        primary: '#0ea5e9',    # Sky blue (Twitter color)
        success: '#10b981',    # Green
        warning: '#f59e0b',    # Amber
        danger: '#ef4444',     # Red
        purple: '#8b5cf6',     # Purple
        gray: '#6b7280'        # Gray
      },
      chart_colors: {
        tag_counts: ['#0ea5e9', '#8B5CF6', '#EC4899', '#14B8A6', '#F59E0B'],
        tag_interactions: ['#0284c7', '#7C3AED', '#D97706', '#0EA5E9', '#EF4444'],
        profile_counts: ['#0ea5e9', '#F97316', '#10B981', '#F59E0B', '#EC4899'],
        profile_interactions: ['#0284c7', '#6366F1', '#22C55E', '#D97706', '#EF4444']
      }
    }
  end

  # Get color from config
  # @param key [Symbol] Color key
  # @return [String] Hex color code
  def color(key)
    config[:colors][key] || config[:colors][:primary]
  end

  # Get chart colors for specific chart type
  # @param chart_type [Symbol] Chart type key
  # @return [Array<String>] Array of hex colors
  def chart_colors(chart_type)
    config[:chart_colors][chart_type] || []
  end

  private

  # Format number with delimiter
  # @param number [Integer, Float] Number to format
  # @return [String] Formatted number
  def format_number(number)
    return '0' if number.nil? || number.zero?
    number.to_s.reverse.scan(/\d{1,3}/).join('.').reverse
  end

  # Get days range from constant or default
  # @return [Integer] Days range
  def days_range
    defined?(DAYS_RANGE) ? DAYS_RANGE : 7
  end
end


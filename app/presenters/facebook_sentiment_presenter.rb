# frozen_string_literal: true

# Presenter for Facebook sentiment analysis
# Encapsulates Facebook-specific sentiment logic and data formatting
# 
# Facebook sentiment uses reaction-based continuous scores (-2.0 to +2.0)
# This is different from digital/tag categorical sentiment (positive/neutral/negative)
class FacebookSentimentPresenter
  attr_reader :sentiment_summary, :sentiment_distribution, :sentiment_over_time,
              :reaction_breakdown, :top_positive_posts, :top_negative_posts,
              :controversial_posts, :emotional_trends, :sentiment_trend

  # Initialize presenter with Facebook sentiment data
  #
  # @param options [Hash] Sentiment data from FacebookDashboardServices
  # @option options [Hash] :sentiment_summary Main sentiment metrics
  # @option options [Hash] :sentiment_distribution Distribution by category
  # @option options [Hash] :sentiment_over_time Time series data
  # @option options [Hash] :reaction_breakdown Reaction counts
  # @option options [Array] :top_positive_posts Most positive posts
  # @option options [Array] :top_negative_posts Most negative posts
  # @option options [Array] :controversial_posts Controversial posts
  # @option options [Hash] :emotional_trends Emotional intensity data
  # @option options [Hash] :sentiment_trend 24h trend data
  def initialize(options = {})
    @sentiment_summary = options[:sentiment_summary]
    @sentiment_distribution = options[:sentiment_distribution]
    @sentiment_over_time = options[:sentiment_over_time]
    @reaction_breakdown = options[:reaction_breakdown]
    @top_positive_posts = options[:top_positive_posts] || []
    @top_negative_posts = options[:top_negative_posts] || []
    @controversial_posts = options[:controversial_posts] || []
    @emotional_trends = options[:emotional_trends]
    @sentiment_trend = options[:sentiment_trend]
  end

  # Check if sentiment data is available
  # @return [Boolean] True if sentiment_summary exists
  def has_data?
    @sentiment_summary.present?
  end

  # Get average sentiment score
  # @return [Float, nil] Average sentiment score or nil
  def average_sentiment
    @sentiment_summary[:average_sentiment] if has_data?
  end

  # Get statistical validity information
  # @return [Hash, nil] Validity metrics or nil
  def statistical_validity
    @sentiment_summary[:statistical_validity] if has_data?
  end

  # Check if statistical validity data exists
  # @return [Boolean] True if validity data present
  def has_validity_data?
    statistical_validity.present?
  end

  # Get overall confidence level
  # @return [Float] Confidence level (0.0 to 1.0)
  def overall_confidence
    return 0.0 unless has_validity_data?
    statistical_validity[:overall_confidence] || 0.0
  end

  # Get total reactions count
  # @return [Integer] Total reactions
  def total_reactions
    return 0 unless has_validity_data?
    statistical_validity[:total_reactions] || 0
  end

  # Check if confidence is high (> 70%)
  # @return [Boolean] True if high confidence
  def high_confidence?
    overall_confidence > 0.7
  end

  # Get sentiment trend data
  # @return [Hash, nil] Trend data or nil
  def trend
    @sentiment_trend
  end

  # Check if trend data exists
  # @return [Boolean] True if trend data present
  def has_trend?
    trend.present? && trend[:change_percent].present?
  end

  # Get trend change percentage
  # @return [Float] Percentage change
  def trend_change_percent
    return 0.0 unless has_trend?
    trend[:change_percent] || 0.0
  end

  # Get recent sentiment score from trend
  # @return [Float] Recent score
  def trend_recent_score
    return 0.0 unless has_trend?
    trend[:recent_score] || 0.0
  end

  # Get trend direction
  # @return [String] 'up', 'down', or 'stable'
  def trend_direction
    return 'stable' unless has_trend?
    trend[:direction] || 'stable'
  end

  # Get trend label (localized)
  # @return [String] Trend label
  def trend_label
    return I18n.t('sentiment.trend.stable') unless has_trend?
    I18n.t("sentiment.trend.#{trend_direction}", default: trend[:trend] || 'estable')
  end

  # Check if has positive posts
  # @return [Boolean] True if positive posts exist
  def has_positive_posts?
    @top_positive_posts.any?
  end

  # Check if has negative posts
  # @return [Boolean] True if negative posts exist
  def has_negative_posts?
    @top_negative_posts.any?
  end

  # Check if has controversial posts
  # @return [Boolean] True if controversial posts exist
  def has_controversial_posts?
    @controversial_posts.any?
  end

  # Get controversial posts count
  # @return [Integer] Number of controversial posts
  def controversial_count
    @controversial_posts.size
  end

  # Check if sentiment over time data exists
  # @return [Boolean] True if time series data present
  def has_time_series?
    @sentiment_over_time.present? && @sentiment_over_time.any?
  end

  # Check if sentiment distribution data exists
  # @return [Boolean] True if distribution data present
  def has_distribution?
    @sentiment_distribution.present?
  end

  # Check if reaction breakdown data exists
  # @return [Boolean] True if reaction data present
  def has_reaction_breakdown?
    @reaction_breakdown.present?
  end

  # Get formatted sentiment score with precision
  # @param score [Float] Sentiment score
  # @param precision [Integer] Decimal places
  # @return [String] Formatted score
  def formatted_score(score, precision: 2)
    return '0.0' if score.nil?
    sprintf("%.#{precision}f", score)
  end

  # Get chart data for sentiment over time
  # Formatted for Chartkick
  # @return [Hash] Chart data
  def sentiment_time_series_data
    return {} unless has_time_series?
    @sentiment_over_time
  end

  # Get chart data for sentiment distribution
  # Formatted for Chartkick pie chart
  # @return [Array<Array>] Chart data [[label, value], ...]
  def sentiment_distribution_data
    return [] unless has_distribution?
    
    @sentiment_distribution.map do |category, data|
      [I18n.t("sentiment.facebook.#{category}", default: category.to_s.titleize), data[:percentage]]
    end
  end

  # Get chart data for reaction breakdown
  # Formatted for Chartkick column chart
  # @return [Hash] Chart data
  def reaction_breakdown_data
    return {} unless has_reaction_breakdown?
    
    @reaction_breakdown.transform_keys do |reaction|
      I18n.t("sentiment.reactions.#{reaction}", default: reaction.to_s.titleize)
    end
  end

  # Sentiment configuration for views
  # @return [Hash] Configuration hash
  def config
    {
      min_score: -2.0,
      max_score: 2.0,
      score_range: 4.0,
      high_confidence_threshold: 0.7,
      chart_colors: {
        primary: '#8b5cf6',    # Purple
        positive: '#10b981',   # Green
        negative: '#ef4444',   # Red
        neutral: '#94a3b8'     # Gray
      }
    }
  end

  # Get color for chart based on config
  # @param key [Symbol] Color key
  # @return [String] Hex color code
  def chart_color(key)
    config[:chart_colors][key] || '#6b7280'
  end
end


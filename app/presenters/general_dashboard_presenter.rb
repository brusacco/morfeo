# frozen_string_literal: true

# Presenter for General Dashboard (cross-channel analytics)
# Encapsulates CEO-level reporting logic combining Digital, Facebook, and Twitter data
class GeneralDashboardPresenter
  include ActionView::Helpers::NumberHelper
  include PdfConstants

  attr_reader :data, :topic, :start_date, :end_date

  # Initialize presenter with aggregated dashboard data
  #
  # @param data [Hash] Data from GeneralDashboardServices::AggregatorService
  # @param topic [Topic] The topic being analyzed
  # @param start_date [DateTime] Start of analysis period
  # @param end_date [DateTime] End of analysis period
  def initialize(data:, topic: nil, start_date: nil, end_date: nil)
    @data = data
    @topic = topic
    @start_date = start_date
    @end_date = end_date
  end

  # === Executive Summary Methods ===

  def executive_summary
    data[:executive_summary] || {}
  end

  def total_mentions
    executive_summary[:total_mentions] || 0
  end

  def total_interactions
    executive_summary[:total_interactions] || 0
  end

  def total_reach
    executive_summary[:total_reach] || 0
  end

  def average_sentiment
    executive_summary[:average_sentiment] || 0
  end

  def formatted_total_mentions
    number_with_delimiter(total_mentions, delimiter: NUMBER_DELIMITER)
  end

  def formatted_total_interactions
    number_with_delimiter(total_interactions, delimiter: NUMBER_DELIMITER)
  end

  def formatted_total_reach
    number_with_delimiter(total_reach, delimiter: NUMBER_DELIMITER)
  end

  def formatted_average_sentiment
    sprintf('%.2f', average_sentiment)
  end

  # === Channel Performance Methods ===

  def channel_performance
    data[:channel_performance] || {}
  end

  def digital_performance
    channel_performance[:digital] || default_channel_data
  end

  def facebook_performance
    channel_performance[:facebook] || default_channel_data
  end

  def twitter_performance
    channel_performance[:twitter] || default_channel_data
  end

  def dominant_channel
    performances = {
      digital: digital_performance[:mentions],
      facebook: facebook_performance[:mentions],
      twitter: twitter_performance[:mentions]
    }
    performances.max_by { |_k, v| v }&.first || :digital
  end

  def dominant_channel_name
    I18n.t("pdf.channels.#{dominant_channel}")
  end

  # === Sentiment Analysis Methods ===

  def sentiment_analysis
    data[:sentiment_analysis] || {}
  end

  def overall_sentiment
    sentiment_analysis[:overall] || {}
  end

  def sentiment_distribution
    overall_sentiment[:distribution] || { positive: 0, neutral: 0, negative: 0 }
  end

  def positive_percentage
    sentiment_distribution[:positive] || 0
  end

  def neutral_percentage
    sentiment_distribution[:neutral] || 0
  end

  def negative_percentage
    sentiment_distribution[:negative] || 0
  end

  def sentiment_trend
    overall_sentiment[:trend] || 'stable'
  end

  def sentiment_trend_label
    case sentiment_trend
    when 'improving' then '📈 Mejorando'
    when 'declining' then '📉 Declinando'
    else '➡️ Estable'
    end
  end

  # === Reach Analysis Methods ===

  def reach_analysis
    data[:reach_analysis] || {}
  end

  def estimated_total_reach
    reach_analysis[:estimated_total] || 0
  end

  def reach_by_channel
    reach_analysis[:by_channel] || {}
  end

  def reach_breakdown
    [
      { channel: I18n.t('pdf.channels.digital'), reach: reach_by_channel[:digital] || 0, color: DIGITAL_PRIMARY_COLOR },
      { channel: I18n.t('pdf.channels.facebook'), reach: reach_by_channel[:facebook] || 0, color: FACEBOOK_PRIMARY_COLOR },
      { channel: I18n.t('pdf.channels.twitter'), reach: reach_by_channel[:twitter] || 0, color: TWITTER_PRIMARY_COLOR }
    ]
  end

  # === Competitive Analysis Methods ===

  def competitive_analysis
    data[:competitive_analysis] || {}
  end

  def share_of_voice
    competitive_analysis[:share_of_voice] || 0
  end

  def formatted_share_of_voice
    "#{share_of_voice.round(1)}%"
  end

  def share_of_voice_status
    case share_of_voice
    when 0...5 then { label: 'Muy Baja', color: '#ef4444' }
    when 5...15 then { label: 'Baja', color: '#f59e0b' }
    when 15...30 then { label: 'Buena', color: '#10b981' }
    when 30...50 then { label: 'Fuerte', color: '#10b981' }
    else { label: 'Dominante', color: '#10b981' }
    end
  end

  # === Temporal Intelligence Methods ===

  def temporal_intelligence
    data[:temporal_intelligence] || {}
  end

  def peak_hours
    temporal_intelligence[:peak_hours] || []
  end

  def peak_days
    temporal_intelligence[:peak_days] || []
  end

  def peak_hour_text
    if peak_hours.any?
      hours = peak_hours.first(3).map { |h| "#{h}:00" }.join(', ')
      "Horas pico: #{hours}"
    else
      "No hay datos suficientes"
    end
  end

  def peak_day_text
    if peak_days.any?
      days_map = { 0 => 'Domingo', 1 => 'Lunes', 2 => 'Martes', 3 => 'Miércoles', 4 => 'Jueves', 5 => 'Viernes', 6 => 'Sábado' }
      days = peak_days.first(3).map { |d| days_map[d] }.join(', ')
      "Días pico: #{days}"
    else
      "No hay datos suficientes"
    end
  end

  # === Top Content Methods ===

  def top_content
    data[:top_content] || {}
  end

  def top_digital_entries
    (top_content[:digital] || []).first(MAX_TOP_POSTS_PDF)
  end

  def top_facebook_posts
    (top_content[:facebook] || []).first(MAX_TOP_POSTS_PDF)
  end

  def top_twitter_posts
    (top_content[:twitter] || []).first(MAX_TOP_POSTS_PDF)
  end

  def has_digital_content?
    top_digital_entries.any?
  end

  def has_facebook_content?
    top_facebook_posts.any?
  end

  def has_twitter_content?
    top_twitter_posts.any?
  end

  # === Word Analysis Methods ===

  def word_analysis
    data[:word_analysis] || {}
  end

  def top_words
    (word_analysis[:top_words] || []).first(MAX_WORDS_DISPLAY)
  end

  def top_bigrams
    (word_analysis[:top_bigrams] || []).first(MAX_BIGRAMS_DISPLAY)
  end

  def has_word_analysis?
    top_words.any? || top_bigrams.any?
  end

  # === Recommendations Methods ===

  def recommendations
    recs = data[:recommendations]
    return [] unless recs.present?
    
    # Handle both array and hash formats
    return recs if recs.is_a?(Array)
    []
  end

  def has_recommendations?
    recommendations.any?
  end

  def actionable_recommendations
    return [] unless recommendations.is_a?(Array)
    
    # Filter high priority recommendations if they have that structure
    high_priority = recommendations.select do |rec|
      rec.is_a?(Hash) && rec[:priority] == 'high'
    end
    
    # If no high priority found, return first 5
    high_priority.any? ? high_priority.first(5) : recommendations.first(5)
  end

  # === Chart Data Methods ===

  def channel_mentions_chart_data
    {
      I18n.t('pdf.channels.digital') => digital_performance[:mentions],
      I18n.t('pdf.channels.facebook') => facebook_performance[:mentions],
      I18n.t('pdf.channels.twitter') => twitter_performance[:mentions]
    }
  end

  def channel_interactions_chart_data
    {
      I18n.t('pdf.channels.digital') => digital_performance[:interactions],
      I18n.t('pdf.channels.facebook') => facebook_performance[:interactions],
      I18n.t('pdf.channels.twitter') => twitter_performance[:interactions]
    }
  end

  def channel_reach_chart_data
    {
      I18n.t('pdf.channels.digital') => digital_performance[:reach],
      I18n.t('pdf.channels.facebook') => facebook_performance[:reach],
      I18n.t('pdf.channels.twitter') => twitter_performance[:reach]
    }
  end

  def sentiment_distribution_chart_data
    {
      I18n.t('sentiment.positive') => sentiment_distribution[:positive],
      I18n.t('sentiment.neutral') => sentiment_distribution[:neutral],
      I18n.t('sentiment.negative') => sentiment_distribution[:negative]
    }
  end

  def share_of_voice_chart_data
    {
      topic.name => share_of_voice,
      'Otros Tópicos' => (100 - share_of_voice)
    }
  end

  # === KPI Metrics for PDF ===

  def kpi_metrics
    [
      {
        label: I18n.t('pdf.metrics.total_mentions'),
        value: formatted_total_mentions,
        icon: '📊',
        color: '#1e3a8a'
      },
      {
        label: I18n.t('pdf.metrics.interactions'),
        value: formatted_total_interactions,
        icon: '💬',
        color: '#10b981'
      },
      {
        label: I18n.t('pdf.metrics.reach'),
        value: formatted_total_reach,
        icon: '🎯',
        color: '#f59e0b'
      },
      {
        label: I18n.t('pdf.metrics.sentiment'),
        value: formatted_average_sentiment,
        icon: sentiment_emoji,
        color: sentiment_color
      }
    ]
  end

  def channel_performance_metrics
    [
      {
        channel: I18n.t('pdf.channels.digital'),
        mentions: digital_performance[:mentions],
        interactions: digital_performance[:interactions],
        reach: digital_performance[:reach],
        color: DIGITAL_PRIMARY_COLOR
      },
      {
        channel: I18n.t('pdf.channels.facebook'),
        mentions: facebook_performance[:mentions],
        interactions: facebook_performance[:interactions],
        reach: facebook_performance[:reach],
        color: FACEBOOK_PRIMARY_COLOR
      },
      {
        channel: I18n.t('pdf.channels.twitter'),
        mentions: twitter_performance[:mentions],
        interactions: twitter_performance[:interactions],
        reach: twitter_performance[:reach],
        color: TWITTER_PRIMARY_COLOR
      }
    ]
  end

  # === Helper Methods ===

  def period_description
    return I18n.t('pdf.period.analyzed_period') unless start_date && end_date
    
    days = ((end_date - start_date) / 1.day).round
    I18n.t('pdf.period.last_n_days', count: days)
  end

  def sentiment_emoji
    case average_sentiment
    when 0.5..Float::INFINITY then '😊'
    when -0.5..0.5 then '😐'
    else '☹️'
    end
  end

  def sentiment_color
    case average_sentiment
    when 0.5..Float::INFINITY then SENTIMENT_POSITIVE_COLOR
    when -0.5..0.5 then SENTIMENT_NEUTRAL_COLOR
    else SENTIMENT_NEGATIVE_COLOR
    end
  end

  def sentiment_text
    case average_sentiment
    when 0.5..Float::INFINITY then 'positivo'
    when -0.5..0.5 then 'neutral'
    else 'negativo'
    end
  end

  private

  def default_channel_data
    {
      mentions: 0,
      interactions: 0,
      reach: 0,
      average_interactions: 0
    }
  end
end


# frozen_string_literal: true

# Helper methods for PDF generation
# Provides utilities for formatting data in PDF reports
module PdfHelper
  include PdfConstants

  # Format number with delimiter for PDF display
  # @param number [Integer, Float] Number to format
  # @return [String] Formatted number with dots as thousands separator
  def pdf_format_number(number)
    return '0' if number.nil? || number.zero?
    number.to_s.reverse.scan(/\d{1,3}/).join(NUMBER_DELIMITER).reverse
  end

  # Get icon emoji for metric type
  # @param type [Symbol] Metric type (:posts, :interactions, :views, :average, etc.)
  # @return [String] Emoji icon
  def pdf_metric_icon(type)
    icons = {
      posts: '📝',
      tweets: '🐦',
      entries: '📰',
      interactions: '📊',
      views: '👁️',
      average: '📈',
      likes: '❤️',
      retweets: '🔄',
      replies: '💬',
      shares: '🔗',
      comments: '💭',
      reactions: '👍',
      reach: '🎯',
      engagement: '⚡',
      sentiment: '😊',
      positive: '😄',
      neutral: '😐',
      negative: '☹️'
    }
    icons[type] || '📌'
  end

  # Build KPI metrics array from presenter data
  # @param presenter [Object] Dashboard presenter (TwitterDashboardPresenter, FacebookSentimentPresenter, etc.)
  # @param type [Symbol] Dashboard type (:twitter, :facebook, :digital)
  # @return [Array<Hash>] Array of metric hashes for PDF
  def build_pdf_kpi_metrics(presenter, type)
    case type
    when :twitter
      [
        {
          label: I18n.t('twitter.kpis.tweets'),
          value: presenter.formatted_total_posts,
          icon: pdf_metric_icon(:tweets)
        },
        {
          label: I18n.t('twitter.kpis.interactions'),
          value: presenter.formatted_total_interactions,
          icon: pdf_metric_icon(:interactions)
        },
        {
          label: I18n.t('twitter.kpis.views'),
          value: presenter.formatted_total_views,
          icon: pdf_metric_icon(:views)
        },
        {
          label: I18n.t('twitter.kpis.average'),
          value: presenter.formatted_average_interactions,
          icon: pdf_metric_icon(:average)
        }
      ]
    when :facebook
      [
        {
          label: I18n.t('pdf.metrics.posts'),
          value: pdf_format_number(presenter.instance_variable_get(:@total_posts) || 0),
          icon: pdf_metric_icon(:posts)
        },
        {
          label: I18n.t('pdf.metrics.interactions'),
          value: pdf_format_number(presenter.instance_variable_get(:@total_interactions) || 0),
          icon: pdf_metric_icon(:interactions)
        },
        {
          label: I18n.t('pdf.metrics.views'),
          value: pdf_format_number(presenter.instance_variable_get(:@total_views) || 0),
          icon: pdf_metric_icon(:views)
        },
        {
          label: I18n.t('pdf.metrics.average'),
          value: pdf_format_number(presenter.instance_variable_get(:@average_interactions) || 0),
          icon: pdf_metric_icon(:average)
        }
      ]
    when :digital
      [] # Digital uses different structure, handle in view
    else
      []
    end
  end

  # Build chart configuration for PDF
  # @param title [String] Chart title
  # @param data [Hash] Chart data
  # @param type [Symbol] Chart type (:column_chart, :line_chart, :pie_chart, :area_chart)
  # @param options [Hash] Additional chart options
  # @return [Hash] Chart configuration
  def build_pdf_chart_config(title:, data:, type: :column_chart, **options)
    {
      title: title,
      data: data,
      type: type,
      options: options
    }
  end

  # Format date range for PDF header
  # @param days_range [Integer] Number of days
  # @param start_date [Date, nil] Optional start date
  # @param end_date [Date, nil] Optional end date
  # @return [String] Formatted date range
  def pdf_date_range(days_range: nil, start_date: nil, end_date: nil)
    if start_date && end_date
      I18n.t('pdf.period.from_to', from: start_date.strftime('%d/%m/%Y'), to: end_date.strftime('%d/%m/%Y'))
    elsif days_range
      I18n.t('pdf.period.last_n_days', count: days_range)
    else
      I18n.t('pdf.period.analyzed_period')
    end
  end

  # Get sentiment emoji for score
  # @param score [Float] Sentiment score (for Facebook: -2.0 to +2.0, for Digital: 0-2)
  # @param system [Symbol] :facebook or :digital
  # @return [String] Emoji
  def pdf_sentiment_emoji(score, system: :facebook)
    return '❓' if score.nil?

    if system == :facebook
      # Facebook: continuous score -2.0 to +2.0
      case score
      when FACEBOOK_SENTIMENT_VERY_POSITIVE..Float::INFINITY then '😊'
      when FACEBOOK_SENTIMENT_POSITIVE..FACEBOOK_SENTIMENT_VERY_POSITIVE then '🙂'
      when FACEBOOK_SENTIMENT_NEUTRAL_MIN..FACEBOOK_SENTIMENT_NEUTRAL_MAX then '😐'
      when FACEBOOK_SENTIMENT_VERY_NEGATIVE..FACEBOOK_SENTIMENT_NEGATIVE then '☹️'
      else '😠'
      end
    else
      # Digital: categorical 0=neutral, 1=positive, 2=negative
      case score.to_i
      when 1 then '😊'
      when 2 then '☹️'
      else '😐'
      end
    end
  end

  # Calculate percentage
  # @param part [Numeric] Part value
  # @param total [Numeric] Total value
  # @param precision [Integer] Decimal places
  # @return [String] Formatted percentage
  def pdf_percentage(part, total, precision: PERCENTAGE_PRECISION)
    return '0%' if total.nil? || total.zero?
    percentage = (part.to_f / total * 100).round(precision)
    "#{percentage}%"
  end

  # Get localized PDF title
  # @param type [Symbol] PDF type (:digital, :facebook, :twitter)
  # @param topic_name [String] Topic name
  # @return [String] Localized title
  def pdf_title(type, topic_name)
    title_key = "pdf.titles.#{type}_report"
    "#{I18n.t(title_key)}: #{topic_name}"
  end

  # Get localized section title
  # @param section [Symbol] Section identifier
  # @return [String] Localized section title
  def pdf_section_title(section)
    I18n.t("pdf.sections.#{section}")
  end

  # Get localized metric label
  # @param metric [Symbol] Metric identifier
  # @return [String] Localized metric label
  def pdf_metric_label(metric)
    I18n.t("pdf.metrics.#{metric}")
  end

  # Get localized chart title
  # @param chart [Symbol] Chart identifier
  # @return [String] Localized chart title
  def pdf_chart_title(chart)
    I18n.t("pdf.charts.#{chart}")
  end
end


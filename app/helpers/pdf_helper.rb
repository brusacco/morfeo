# frozen_string_literal: true

# Helper methods for PDF generation
# Provides utilities for formatting data in PDF reports
module PdfHelper
  # Format number with delimiter for PDF display
  # @param number [Integer, Float] Number to format
  # @return [String] Formatted number with dots as thousands separator
  def pdf_format_number(number)
    return '0' if number.nil? || number.zero?
    number.to_s.reverse.scan(/\d{1,3}/).join('.').reverse
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
          label: 'Posts',
          value: pdf_format_number(presenter.instance_variable_get(:@total_posts) || 0),
          icon: pdf_metric_icon(:posts)
        },
        {
          label: 'Interacciones',
          value: pdf_format_number(presenter.instance_variable_get(:@total_interactions) || 0),
          icon: pdf_metric_icon(:interactions)
        },
        {
          label: 'Vistas',
          value: pdf_format_number(presenter.instance_variable_get(:@total_views) || 0),
          icon: pdf_metric_icon(:views)
        },
        {
          label: 'Promedio',
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
      "#{start_date.strftime('%d/%m/%Y')} - #{end_date.strftime('%d/%m/%Y')}"
    elsif days_range
      "Últimos #{days_range} días"
    else
      "Período analizado"
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
      when 1.5..Float::INFINITY then '😊'
      when 0.5..1.5 then '🙂'
      when -0.5..0.5 then '😐'
      when -1.5..-0.5 then '☹️'
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
  def pdf_percentage(part, total, precision: 1)
    return '0%' if total.nil? || total.zero?
    percentage = (part.to_f / total * 100).round(precision)
    "#{percentage}%"
  end
end


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

  # Enhanced chart configuration for better print quality
  # @param title [String] Chart title
  # @param data [Hash] Chart data
  # @param type [Symbol] Chart type
  # @param options [Hash] Additional options
  # @return [Hash] Enhanced chart configuration
  def build_pdf_chart_config_enhanced(title:, data:, type: :column_chart, **options)
    # Enhanced library options for print quality
    enhanced_options = options.dup
    enhanced_options[:library] ||= {}
    
    enhanced_options[:library][:chart] ||= {}
    enhanced_options[:library][:chart][:style] = {
      fontFamily: 'Inter, -apple-system, sans-serif',
      fontSize: '11pt'
    }
    
    enhanced_options[:library][:xAxis] ||= {}
    enhanced_options[:library][:xAxis][:labels] = {
      style: { fontSize: '10pt', fontWeight: '600', color: '#374151' },
      rotation: (type == :column_chart ? -45 : 0)
    }
    enhanced_options[:library][:xAxis][:gridLineWidth] = 1
    enhanced_options[:library][:xAxis][:gridLineColor] = '#f3f4f6'
    
    enhanced_options[:library][:yAxis] ||= {}
    enhanced_options[:library][:yAxis][:labels] = {
      style: { fontSize: '10pt', fontWeight: '600', color: '#374151' }
    }
    enhanced_options[:library][:yAxis][:gridLineWidth] = 1
    enhanced_options[:library][:yAxis][:gridLineColor] = '#f3f4f6'
    
    build_pdf_chart_config(title: title, data: data, type: type, **enhanced_options)
  end

  # Print-friendly color palette
  def pdf_print_colors
    PdfColors::CHART_PALETTE
  end
  
  # Get primary color for report type
  def pdf_primary_color(report_type)
    PdfColors.primary_color(report_type)
  end
  
  # Get sentiment color
  def pdf_sentiment_color_value(sentiment)
    PdfColors.sentiment_color(sentiment)
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

  # Configure Google Charts for PDF with responsive height based on date range
  # Optimized for exact A4 page fitting (1 slide = 1 page)
  # @param days_range [Integer] Number of days in the date range (7-60+)
  # @return [Hash] Google Charts library configuration
  def pdf_chart_config_for_range(days_range)
    # Reduced heights to fit 2 charts + headers + insights in 1 A4 page
    # A4 content area: 729pt height
    # Slide padding: 48pt (24pt top + 24pt bottom)
    # Header: ~60pt
    # 2 charts + headers + insights: ~600pt
    # Each chart section: ~250pt max
    height = case days_range
             when 0..7 then '180px'    # Reduced from 240px
             when 8..14 then '190px'   # Reduced from 260px
             when 15..30 then '200px'  # Reduced from 280px
             when 31..60 then '210px'  # Reduced from 300px
             else '220px'              # Reduced from 320px (60+ days)
             end

    # Adjust chartArea bottom padding for rotated labels
    # Reduced to fit compact layout
    bottom = case days_range
             when 0..7 then 60      # Reduced from 80
             when 8..14 then 65     # Reduced from 90
             when 15..30 then 70    # Reduced from 100
             when 31..60 then 75    # Reduced from 110
             else 80                # Reduced from 120 (60+ days)
             end

    {
      width: '680px', # Fixed width for consistent PDF layout
      height: height,
      library: {
        backgroundColor: 'transparent',
        chartArea: {
          width: '94%', # Maximize chart area (6% for axis labels)
          height: '94%',
          top: 30,      # Reduced from 40
          left: 50,     # Reduced from 60
          right: 15,    # Reduced from 20
          bottom: bottom
        },
        hAxis: {
          textStyle: {
            fontSize: 9,  # Reduced from 10
            fontName: 'Inter, sans-serif',
            color: '#374151'
          },
          slantedText: true, # Enable rotated labels
          slantedTextAngle: 45, # 45° rotation
          gridlines: { color: '#f3f4f6' },
          minorGridlines: { count: 0 }
        },
        vAxis: {
          textStyle: {
            fontSize: 9,  # Reduced from 10
            fontName: 'Inter, sans-serif',
            color: '#374151'
          },
          gridlines: { color: '#f3f4f6' },
          minorGridlines: { count: 0 }
        },
        legend: {
          position: 'none', # Removed legend to save space
          alignment: 'center',
          textStyle: {
            fontSize: 10,  # Reduced from 11
            fontName: 'Inter, sans-serif',
            color: '#1f2937'
          }
        },
        animation: {
          duration: 0 # Disable animations for faster PDF rendering
        }
      }
    }
  end
end


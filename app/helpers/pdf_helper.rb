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

  # Generate Heroicons SVG for PDF
  # @param name [Symbol] Icon name from Heroicons
  # @param size [String] Size in pt (e.g., '20pt', '24pt')
  # @param color [String] Hex color code
  # @param variant [Symbol] :outline, :solid, :mini, :micro (default: :outline)
  # @return [String] Inline SVG HTML
  def heroicon_svg(name, size: '24pt', color: 'currentColor', variant: :outline)
    # Heroicons SVG paths - usando variante outline (24x24, 1.5px stroke)
    icons = {
      # Métricas y Stats
      document_text: '<path stroke-linecap="round" stroke-linejoin="round" d="M19.5 14.25v-2.625a3.375 3.375 0 0 0-3.375-3.375h-1.5A1.125 1.125 0 0 1 13.5 7.125v-1.5a3.375 3.375 0 0 0-3.375-3.375H8.25m0 12.75h7.5m-7.5 3H12M10.5 2.25H5.625c-.621 0-1.125.504-1.125 1.125v17.25c0 .621.504 1.125 1.125 1.125h12.75c.621 0 1.125-.504 1.125-1.125V11.25a9 9 0 0 0-9-9Z" />',
      
      chart_bar: '<path stroke-linecap="round" stroke-linejoin="round" d="M3 13.125C3 12.504 3.504 12 4.125 12h2.25c.621 0 1.125.504 1.125 1.125v6.75C7.5 20.496 6.996 21 6.375 21h-2.25A1.125 1.125 0 0 1 3 19.875v-6.75ZM9.75 8.625c0-.621.504-1.125 1.125-1.125h2.25c.621 0 1.125.504 1.125 1.125v11.25c0 .621-.504 1.125-1.125 1.125h-2.25a1.125 1.125 0 0 1-1.125-1.125V8.625ZM16.5 4.125c0-.621.504-1.125 1.125-1.125h2.25C20.496 3 21 3.504 21 4.125v15.75c0 .621-.504 1.125-1.125 1.125h-2.25a1.125 1.125 0 0 1-1.125-1.125V4.125Z" />',
      
      eye: '<path stroke-linecap="round" stroke-linejoin="round" d="M2.036 12.322a1.012 1.012 0 0 1 0-.639C3.423 7.51 7.36 4.5 12 4.5c4.638 0 8.573 3.007 9.963 7.178.07.207.07.431 0 .639C20.577 16.49 16.64 19.5 12 19.5c-4.638 0-8.573-3.007-9.963-7.178Z" /><path stroke-linecap="round" stroke-linejoin="round" d="M15 12a3 3 0 1 1-6 0 3 3 0 0 1 6 0Z" />',
      
      arrow_trending_up: '<path stroke-linecap="round" stroke-linejoin="round" d="M2.25 18 9 11.25l4.306 4.306a11.95 11.95 0 0 1 5.814-5.518l2.74-1.22m0 0-5.94-2.281m5.94 2.28-2.28 5.941" />',
      
      users: '<path stroke-linecap="round" stroke-linejoin="round" d="M15 19.128a9.38 9.38 0 0 0 2.625.372 9.337 9.337 0 0 0 4.121-.952 4.125 4.125 0 0 0-7.533-2.493M15 19.128v-.003c0-1.113-.285-2.16-.786-3.07M15 19.128v.106A12.318 12.318 0 0 1 8.624 21c-2.331 0-4.512-.645-6.374-1.766l-.001-.109a6.375 6.375 0 0 1 11.964-3.07M12 6.375a3.375 3.375 0 1 1-6.75 0 3.375 3.375 0 0 1 6.75 0Zm8.25 2.25a2.625 2.625 0 1 1-5.25 0 2.625 2.625 0 0 1 5.25 0Z" />',
      
      cursor_arrow_ripple: '<path stroke-linecap="round" stroke-linejoin="round" d="M15.042 21.672 13.684 16.6m0 0-2.51 2.225.569-9.47 5.227 7.917-3.286-.672ZM12 2.25V4.5m5.834.166-1.591 1.591M20.25 10.5H18M7.757 14.743l-1.59 1.59M6 10.5H3.75m4.007-4.243-1.59-1.59" />',
      
      newspaper: '<path stroke-linecap="round" stroke-linejoin="round" d="M12 7.5h1.5m-1.5 3h1.5m-7.5 3h7.5m-7.5 3h7.5m3-9h3.375c.621 0 1.125.504 1.125 1.125V18a2.25 2.25 0 0 1-2.25 2.25M16.5 7.5V18a2.25 2.25 0 0 0 2.25 2.25M16.5 7.5V4.875c0-.621-.504-1.125-1.125-1.125H4.125C3.504 3.75 3 4.254 3 4.875V18a2.25 2.25 0 0 0 2.25 2.25h13.5M6 7.5h3v3H6v-3Z" />',
      
      # Temporal y Calendario
      calendar_days: '<path stroke-linecap="round" stroke-linejoin="round" d="M6.75 3v2.25M17.25 3v2.25M3 18.75V7.5a2.25 2.25 0 0 1 2.25-2.25h13.5A2.25 2.25 0 0 1 21 7.5v11.25m-18 0A2.25 2.25 0 0 0 5.25 21h13.5A2.25 2.25 0 0 0 21 18.75m-18 0v-7.5A2.25 2.25 0 0 1 5.25 9h13.5A2.25 2.25 0 0 1 21 11.25v7.5m-9-6h.008v.008H12v-.008ZM12 15h.008v.008H12V15Zm0 2.25h.008v.008H12v-.008ZM9.75 15h.008v.008H9.75V15Zm0 2.25h.008v.008H9.75v-.008ZM7.5 15h.008v.008H7.5V15Zm0 2.25h.008v.008H7.5v-.008Zm6.75-4.5h.008v.008h-.008v-.008Zm0 2.25h.008v.008h-.008V15Zm0 2.25h.008v.008h-.008v-.008Zm2.25-4.5h.008v.008H16.5v-.008Zm0 2.25h.008v.008H16.5V15Z" />',
      
      clock: '<path stroke-linecap="round" stroke-linejoin="round" d="M12 6v6h4.5m4.5 0a9 9 0 1 1-18 0 9 9 0 0 1 18 0Z" />',
      
      # Navegación y UI
      chevron_up: '<path stroke-linecap="round" stroke-linejoin="round" d="m4.5 15.75 7.5-7.5 7.5 7.5" />',
      
      arrow_up: '<path stroke-linecap="round" stroke-linejoin="round" d="M4.5 10.5 12 3m0 0 7.5 7.5M12 3v18" />',
      
      # Sentimiento y Feedback
      face_smile: '<path stroke-linecap="round" stroke-linejoin="round" d="M15.182 15.182a4.5 4.5 0 0 1-6.364 0M21 12a9 9 0 1 1-18 0 9 9 0 0 1 18 0ZM9.75 9.75c0 .414-.168.75-.375.75S9 10.164 9 9.75 9.168 9 9.375 9s.375.336.375.75Zm-.375 0h.008v.015h-.008V9.75Zm5.625 0c0 .414-.168.75-.375.75s-.375-.336-.375-.75.168-.75.375-.75.375.336.375.75Zm-.375 0h.008v.015h-.008V9.75Z" />',
      
      face_frown: '<path stroke-linecap="round" stroke-linejoin="round" d="M15.182 16.318A4.486 4.486 0 0 0 12.016 15a4.486 4.486 0 0 0-3.198 1.318M21 12a9 9 0 1 1-18 0 9 9 0 0 1 18 0ZM9.75 9.75c0 .414-.168.75-.375.75S9 10.164 9 9.75 9.168 9 9.375 9s.375.336.375.75Zm-.375 0h.008v.015h-.008V9.75Zm5.625 0c0 .414-.168.75-.375.75s-.375-.336-.375-.75.168-.75.375-.75.375.336.375.75Zm-.375 0h.008v.015h-.008V9.75Z" />',
      
      # Social Media
      chat_bubble_left_right: '<path stroke-linecap="round" stroke-linejoin="round" d="M20.25 8.511c.884.284 1.5 1.128 1.5 2.097v4.286c0 1.136-.847 2.1-1.98 2.193-.34.027-.68.052-1.02.072v3.091l-3-3c-1.354 0-2.694-.055-4.02-.163a2.115 2.115 0 0 1-.825-.242m9.345-8.334a2.126 2.126 0 0 0-.476-.095 48.64 48.64 0 0 0-8.048 0c-1.131.094-1.976 1.057-1.976 2.192v4.286c0 .837.46 1.58 1.155 1.951m9.345-8.334V6.637c0-1.621-1.152-3.026-2.76-3.235A48.455 48.455 0 0 0 11.25 3c-2.115 0-4.198.137-6.24.402-1.608.209-2.76 1.614-2.76 3.235v6.226c0 1.621 1.152 3.026 2.76 3.235.577.075 1.157.14 1.74.194V21l4.155-4.155" />',
      
      chat_bubble_oval_left: '<path stroke-linecap="round" stroke-linejoin="round" d="M12 20.25c4.97 0 9-3.694 9-8.25s-4.03-8.25-9-8.25S3 7.444 3 12c0 2.104.859 4.023 2.273 5.48.432.447.74 1.04.586 1.641a4.483 4.483 0 0 1-.923 1.785A5.969 5.969 0 0 0 6 21c1.282 0 2.47-.402 3.445-1.087.81.22 1.668.337 2.555.337Z" />',
      
      hashtag: '<path stroke-linecap="round" stroke-linejoin="round" d="M5.25 8.25h15m-16.5 7.5h15m-1.8-13.5-3.9 19.5m-2.1-19.5-3.9 19.5" />',
      
      at_symbol: '<path stroke-linecap="round" stroke-linejoin="round" d="M16.5 12a4.5 4.5 0 1 1-9 0 4.5 4.5 0 0 1 9 0Zm0 0c0 1.657 1.007 3 2.25 3S21 13.657 21 12a9 9 0 1 0-2.636 6.364M16.5 12V8.25" />',
      
      # Interacciones y Métricas
      heart: '<path stroke-linecap="round" stroke-linejoin="round" d="M21 8.25c0-2.485-2.099-4.5-4.688-4.5-1.935 0-3.597 1.126-4.312 2.733-.715-1.607-2.377-2.733-4.313-2.733C5.1 3.75 3 5.765 3 8.25c0 7.22 9 12 9 12s9-4.78 9-12Z" />',
      
      arrow_path_rounded_square: '<path stroke-linecap="round" stroke-linejoin="round" d="M19.5 12c0-1.232-.046-2.453-.138-3.662a4.006 4.006 0 0 0-3.7-3.7 48.678 48.678 0 0 0-7.324 0 4.006 4.006 0 0 0-3.7 3.7c-.017.22-.032.441-.046.662M19.5 12l3-3m-3 3-3-3m-12 3c0 1.232.046 2.453.138 3.662a4.006 4.006 0 0 0 3.7 3.7 48.656 48.656 0 0 0 7.324 0 4.006 4.006 0 0 0 3.7-3.7c.017-.22.032-.441.046-.662M4.5 12l3 3m-3-3-3 3" />',
      
      share: '<path stroke-linecap="round" stroke-linejoin="round" d="M7.217 10.907a2.25 2.25 0 1 0 0 2.186m0-2.186c.18.324.283.696.283 1.093s-.103.77-.283 1.093m0-2.186 9.566-5.314m-9.566 7.5 9.566 5.314m0 0a2.25 2.25 0 1 0 3.935 2.186 2.25 2.25 0 0 0-3.935-2.186Zm0-12.814a2.25 2.25 0 1 0 3.933-2.185 2.25 2.25 0 0 0-3.933 2.185Z" />',
      
      # Análisis y Data
      chart_pie: '<path stroke-linecap="round" stroke-linejoin="round" d="M10.5 6a7.5 7.5 0 1 0 7.5 7.5h-7.5V6Z" /><path stroke-linecap="round" stroke-linejoin="round" d="M13.5 10.5H21A7.5 7.5 0 0 0 13.5 3v7.5Z" />',
      
      presentation_chart_line: '<path stroke-linecap="round" stroke-linejoin="round" d="M3.75 3v11.25A2.25 2.25 0 0 0 6 16.5h2.25M3.75 3h-1.5m1.5 0h16.5m0 0h1.5m-1.5 0v11.25A2.25 2.25 0 0 1 18 16.5h-2.25m-7.5 0h7.5m-7.5 0-1 3m8.5-3 1 3m0 0 .5 1.5m-.5-1.5h-9.5m0 0-.5 1.5m.75-9 3-3 2.148 2.148A12.061 12.061 0 0 1 16.5 7.605" />',
      
      sparkles: '<path stroke-linecap="round" stroke-linejoin="round" d="M9.813 15.904 9 18.75l-.813-2.846a4.5 4.5 0 0 0-3.09-3.09L2.25 12l2.846-.813a4.5 4.5 0 0 0 3.09-3.09L9 5.25l.813 2.846a4.5 4.5 0 0 0 3.09 3.09L15.75 12l-2.846.813a4.5 4.5 0 0 0-3.09 3.09ZM18.259 8.715 18 9.75l-.259-1.035a3.375 3.375 0 0 0-2.455-2.456L14.25 6l1.036-.259a3.375 3.375 0 0 0 2.455-2.456L18 2.25l.259 1.035a3.375 3.375 0 0 0 2.456 2.456L21.75 6l-1.035.259a3.375 3.375 0 0 0-2.456 2.456ZM16.894 20.567 16.5 21.75l-.394-1.183a2.25 2.25 0 0 0-1.423-1.423L13.5 18.75l1.183-.394a2.25 2.25 0 0 0 1.423-1.423l.394-1.183.394 1.183a2.25 2.25 0 0 0 1.423 1.423l1.183.394-1.183.394a2.25 2.25 0 0 0-1.423 1.423Z" />',
      
      # Medios y Contenido
      building_office: '<path stroke-linecap="round" stroke-linejoin="round" d="M3.75 21h16.5M4.5 3h15M5.25 3v18m13.5-18v18M9 6.75h1.5m-1.5 3h1.5m-1.5 3h1.5m3-6H15m-1.5 3H15m-1.5 3H15M9 21v-3.375c0-.621.504-1.125 1.125-1.125h3.75c.621 0 1.125.504 1.125 1.125V21" />',
      
      globe_americas: '<path stroke-linecap="round" stroke-linejoin="round" d="m6.115 5.19.319 1.913A6 6 0 0 0 8.11 10.36L9.75 12l-.387.775c-.217.433-.132.956.21 1.298l1.348 1.348c.21.21.329.497.329.795v1.089c0 .426.24.815.622 1.006l.153.076c.433.217.956.132 1.298-.21l.723-.723a8.7 8.7 0 0 0 2.288-4.042 1.087 1.087 0 0 0-.358-1.099l-1.33-1.108c-.251-.21-.582-.299-.905-.245l-1.17.195a1.125 1.125 0 0 1-.98-.314l-.295-.295a1.125 1.125 0 0 1 0-1.591l.13-.132a1.125 1.125 0 0 1 1.3-.21l.603.302a.809.809 0 0 0 1.086-1.086L14.25 7.5l1.256-.837a4.5 4.5 0 0 0 1.528-1.732l.146-.292M6.115 5.19A9 9 0 1 0 17.18 4.64M6.115 5.19A8.965 8.965 0 0 1 12 3c1.929 0 3.716.607 5.18 1.64" />',
      
      light_bulb: '<path stroke-linecap="round" stroke-linejoin="round" d="M12 18v-5.25m0 0a6.01 6.01 0 0 0 1.5-.189m-1.5.189a6.01 6.01 0 0 1-1.5-.189m3.75 7.478a12.06 12.06 0 0 1-4.5 0m3.75 2.383a14.406 14.406 0 0 1-3 0M14.25 18v-.192c0-.983.658-1.823 1.508-2.316a7.5 7.5 0 1 0-7.517 0c.85.493 1.509 1.333 1.509 2.316V18" />'
    }

    path = icons[name.to_sym]
    return '' unless path

    # SVG con viewBox y dimensiones
    <<-HTML.html_safe
      <svg xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" stroke-width="1.5" stroke="#{color}" style="width: #{size}; height: #{size}; display: inline-block; vertical-align: middle;">
        #{path}
      </svg>
    HTML
  end
end


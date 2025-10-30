module ReportsHelper
  # Professional color palette for executive reports
  REPORT_COLORS = {
    primary: '#1e40af',
    primary_light: '#3b82f6',
    success: '#059669',
    success_light: '#10b981',
    warning: '#d97706',
    danger: '#dc2626',
    neutral_dark: '#1f2937',
    neutral: '#6b7280',
    neutral_light: '#f3f4f6',
    background: '#ffffff'
  }.freeze

  # Professional chart color palette (colorblind-safe)
  CHART_COLORS = ['#1e40af', '#059669', '#d97706', '#7c3aed', '#0ea5e9', '#dc2626'].freeze

  # Sentiment colors
  SENTIMENT_COLORS = {
    positive: '#10b981',
    neutral: '#9ca3af',
    negative: '#ef4444'
  }.freeze

  # Format large numbers for executive display
  def format_metric_number(number)
    return '0' if number.nil? || number.zero?

    if number >= 1_000_000
      "#{(number / 1_000_000.0).round(1)}M"
    elsif number >= 1_000
      "#{(number / 1_000.0).round(1)}K"
    else
      number_with_delimiter(number, delimiter: '.')
    end
  end

  # Calculate trend indicator
  def trend_indicator(current, previous)
    return { symbol: '→', color: REPORT_COLORS[:neutral], text: 'Sin cambio' } if previous.nil? || previous.zero?

    change = ((current - previous).to_f / previous * 100).round(1)

    if change > 0
      { symbol: '↑', color: REPORT_COLORS[:success], text: "+#{change}%", positive: true }
    elsif change < 0
      { symbol: '↓', color: REPORT_COLORS[:danger], text: "#{change}%", positive: false }
    else
      { symbol: '→', color: REPORT_COLORS[:neutral], text: '0%', positive: nil }
    end
  end

  # Get sentiment label in Spanish
  def sentiment_label(polarity)
    case polarity&.to_s&.downcase
    when 'positive', '1'
      'Positivo'
    when 'negative', '2'
      'Negativo'
    when 'neutral', '0'
      'Neutral'
    else
      'N/A'
    end
  end

  # Get sentiment color
  def sentiment_color(polarity)
    case polarity&.to_s&.downcase
    when 'positive', '1'
      SENTIMENT_COLORS[:positive]
    when 'negative', '2'
      SENTIMENT_COLORS[:negative]
    else
      SENTIMENT_COLORS[:neutral]
    end
  end

  # Generate page title with proper formatting
  def pdf_page_title(text)
    content_tag(:h1, text, class: 'pdf-page-title')
  end

  # Generate section title with proper formatting
  def pdf_section_title(text, level: 2)
    content_tag("h#{level}".to_sym, text, class: "pdf-section-title-#{level}")
  end

  # Format date range for reports
  def format_date_range(days)
    end_date = Date.current
    start_date = end_date - days.days
    "#{start_date.strftime('%d/%m/%Y')} - #{end_date.strftime('%d/%m/%Y')}"
  end

  # Professional metric card HTML
  def metric_card(label, value, trend: nil, icon: nil, color: REPORT_COLORS[:primary])
    content_tag(:div, class: 'pdf-metric-card') do
      card_content = ''
      
      # Icon (if provided)
      card_content += content_tag(:div, icon, class: 'pdf-metric-icon') if icon.present?
      
      # Label
      card_content += content_tag(:div, label, class: 'pdf-metric-label')
      
      # Value with optional trend
      value_html = content_tag(:div, class: 'pdf-metric-value-container') do
        value_content = content_tag(:span, value, class: 'pdf-metric-value', style: "color: #{color};")
        
        if trend
          value_content += content_tag(:span, 
            trend[:symbol] + ' ' + trend[:text], 
            class: 'pdf-metric-trend',
            style: "color: #{trend[:color]};"
          )
        end
        
        value_content
      end
      
      card_content += value_html
      card_content.html_safe
    end
  end

  # Generate executive summary bullet points
  def executive_summary_bullet(text, type: :info)
    icon = case type
           when :positive then '✓'
           when :negative then '✗'
           when :warning then '⚠'
           else '•'
           end

    color = case type
            when :positive then REPORT_COLORS[:success]
            when :negative then REPORT_COLORS[:danger]
            when :warning then REPORT_COLORS[:warning]
            else REPORT_COLORS[:neutral_dark]
            end

    content_tag(:li, class: 'executive-summary-bullet') do
      content_tag(:span, icon, class: 'bullet-icon', style: "color: #{color};") +
      content_tag(:span, text, class: 'bullet-text')
    end
  end

  # Confidence level badge
  def confidence_badge(level)
    case level
    when :high
      content_tag(:span, 'Alta Confianza', class: 'confidence-badge confidence-high')
    when :medium
      content_tag(:span, 'Confianza Media', class: 'confidence-badge confidence-medium')
    when :low
      content_tag(:span, 'Baja Confianza', class: 'confidence-badge confidence-low')
    end
  end
end

# frozen_string_literal: true

module HomeHelper
  # Sentiment badge styling
  def sentiment_badge_class(score)
    if score >= 40
      'bg-green-100 text-green-800 border-green-300'
    elsif score >= 10
      'bg-lime-100 text-lime-800 border-lime-300'
    elsif score >= -10
      'bg-gray-100 text-gray-800 border-gray-300'
    elsif score >= -40
      'bg-orange-100 text-orange-800 border-orange-300'
    else
      'bg-red-100 text-red-800 border-red-300'
    end
  end

  # Topic trend badge styling
  def trend_badge(direction)
    case direction
    when 'up'
      content_tag(:span, class: 'inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium bg-green-100 text-green-800') do
        concat content_tag(:span, '↑', class: 'mr-1')
        concat 'Creciendo'
      end
    when 'down'
      content_tag(:span, class: 'inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium bg-red-100 text-red-800') do
        concat content_tag(:span, '↓', class: 'mr-1')
        concat 'Declinando'
      end
    else
      content_tag(:span, class: 'inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium bg-gray-100 text-gray-800') do
        concat content_tag(:span, '→', class: 'mr-1')
        concat 'Estable'
      end
    end
  end

  # Trend icon with color
  def trend_icon_with_color(direction)
    case direction
    when 'up'
      content_tag(:span, '↑', class: 'text-green-600 font-bold text-xl')
    when 'down'
      content_tag(:span, '↓', class: 'text-red-600 font-bold text-xl')
    else
      content_tag(:span, '→', class: 'text-gray-600 font-bold text-xl')
    end
  end

  # Alert styling helpers
  def alert_border_color(severity)
    case severity
    when 'high' then 'border-red-500'
    when 'medium' then 'border-yellow-500'
    else 'border-blue-500'
    end
  end

  def alert_bg_color(severity)
    case severity
    when 'high' then 'bg-red-50'
    when 'medium' then 'bg-yellow-50'
    else 'bg-blue-50'
    end
  end

  def alert_text_color(severity)
    case severity
    when 'high' then 'text-red-600'
    when 'medium' then 'text-yellow-600'
    else 'text-blue-600'
    end
  end

  def alert_heading_color(severity)
    case severity
    when 'high' then 'text-red-900'
    when 'medium' then 'text-yellow-900'
    else 'text-blue-900'
    end
  end

  def alert_text_secondary(severity)
    case severity
    when 'high' then 'text-red-700'
    when 'medium' then 'text-yellow-700'
    else 'text-blue-700'
    end
  end

  def alert_icon(type)
    case type
    when 'crisis' then 'fa-solid fa-triangle-exclamation'
    when 'warning' then 'fa-solid fa-exclamation-circle'
    else 'fa-solid fa-info-circle'
    end
  end

  # Channel icon helper
  def channel_icon(channel_key)
    case channel_key
    when :digital then 'fa-solid fa-newspaper'
    when :facebook then 'fa-brands fa-facebook'
    when :twitter then 'fa-brands fa-twitter'
    else 'fa-solid fa-chart-line'
    end
  end

  # Format large numbers with K, M suffixes
  def format_large_number(number)
    return '0' if number.nil? || number.zero?

    if number >= 1_000_000
      "#{(number / 1_000_000.0).round(1)}M"
    elsif number >= 1_000
      "#{(number / 1_000.0).round(1)}K"
    else
      number_with_delimiter(number)
    end
  end

  # Engagement rate badge color
  def engagement_rate_color(rate)
    if rate >= 5.0
      'text-green-600'
    elsif rate >= 2.0
      'text-blue-600'
    elsif rate >= 1.0
      'text-yellow-600'
    else
      'text-gray-600'
    end
  end

  # Quick access button styling
  def dashboard_button_class(type)
    base = 'flex-1 px-3 py-2 text-xs font-medium rounded-lg transition-all duration-200 hover:shadow-md'
    
    case type
    when 'digital'
      "#{base} bg-indigo-50 text-indigo-700 border border-indigo-200 hover:bg-indigo-100"
    when 'facebook'
      "#{base} bg-blue-50 text-blue-700 border border-blue-200 hover:bg-blue-100"
    when 'twitter'
      "#{base} bg-sky-50 text-sky-700 border border-sky-200 hover:bg-sky-100"
    when 'general'
      "#{base} bg-purple-50 text-purple-700 border border-purple-200 hover:bg-purple-100"
    else
      "#{base} bg-gray-50 text-gray-700 border border-gray-200 hover:bg-gray-100"
    end
  end

  # ========================================
  # PHASE 2 HELPERS
  # ========================================

  # Reliability badge for confidence metrics
  def reliability_badge_class(reliability)
    case reliability.to_s
    when 'very_low'
      'bg-red-100 text-red-800 border border-red-300'
    when 'low'
      'bg-amber-100 text-amber-800 border border-amber-300'
    when 'moderate'
      'bg-yellow-100 text-yellow-800 border border-yellow-300'
    when 'good'
      'bg-blue-100 text-blue-800 border border-blue-300'
    when 'high'
      'bg-green-100 text-green-800 border border-green-300'
    else
      'bg-gray-100 text-gray-800 border border-gray-300'
    end
  end

  def reliability_label(reliability)
    case reliability.to_s
    when 'very_low' then 'Muy Baja'
    when 'low' then 'Baja'
    when 'moderate' then 'Moderada'
    when 'good' then 'Buena'
    when 'high' then 'Alta'
    else 'Desconocida'
    end
  end

  def reliability_icon(reliability)
    case reliability.to_s
    when 'very_low' then 'fa-circle-xmark'
    when 'low' then 'fa-circle-exclamation'
    when 'moderate' then 'fa-circle-minus'
    when 'good' then 'fa-circle-check'
    when 'high' then 'fa-circle-check'
    else 'fa-circle-question'
    end
  end

  # Trending status styling
  def trending_badge_class(trending)
    case trending.to_s
    when 'up' then 'bg-green-100 text-green-800 border-green-300'
    when 'down' then 'bg-red-100 text-red-800 border-red-300'
    when 'stable' then 'bg-gray-100 text-gray-700 border-gray-300'
    else 'bg-gray-100 text-gray-700 border-gray-300'
    end
  end

  def trending_icon(trending)
    case trending.to_s
    when 'up' then 'fa-arrow-trend-up'
    when 'down' then 'fa-arrow-trend-down'
    when 'stable' then 'fa-minus'
    else 'fa-minus'
    end
  end

  def trending_label(trending)
    case trending.to_s
    when 'up' then 'En Crecimiento'
    when 'down' then 'En Declive'
    when 'stable' then 'Estable'
    else 'Sin Tendencia'
    end
  end

  # Competitive status styling
  def competitive_status_class(status)
    case status.to_s
    when 'dominant' then 'bg-purple-100 text-purple-900 border-purple-300'
    when 'strong' then 'bg-indigo-100 text-indigo-900 border-indigo-300'
    when 'competitive' then 'bg-blue-100 text-blue-900 border-blue-300'
    else 'bg-gray-100 text-gray-700 border-gray-300'
    end
  end

  def competitive_status_icon(status)
    case status.to_s
    when 'dominant' then 'fa-crown'
    when 'strong' then 'fa-medal'
    when 'competitive' then 'fa-trophy'
    else 'fa-circle'
    end
  end

  def competitive_status_label(status)
    case status.to_s
    when 'dominant' then 'Dominante'
    when 'strong' then 'Fuerte'
    when 'competitive' then 'Competitivo'
    else 'Normal'
    end
  end

  # Rank medal/badge
  def rank_badge(rank)
    case rank
    when 1
      content_tag(:span, class: 'inline-flex items-center text-amber-600 font-semibold') do
        concat content_tag(:i, '', class: 'fas fa-trophy mr-1')
        concat "##{rank}"
      end
    when 2
      content_tag(:span, class: 'inline-flex items-center text-gray-500 font-semibold') do
        concat content_tag(:i, '', class: 'fas fa-medal mr-1')
        concat "##{rank}"
      end
    when 3
      content_tag(:span, class: 'inline-flex items-center text-orange-700 font-semibold') do
        concat content_tag(:i, '', class: 'fas fa-award mr-1')
        concat "##{rank}"
      end
    else
      content_tag(:span, "##{rank}", class: 'text-gray-600 font-semibold')
    end
  end

  # Controversy level styling
  def controversy_badge_class(index)
    case index
    when 0...0.3 then 'bg-green-100 text-green-800'
    when 0.3...0.5 then 'bg-yellow-100 text-yellow-800'
    when 0.5...0.7 then 'bg-amber-100 text-amber-800'
    else 'bg-red-100 text-red-800'
    end
  end

  def controversy_label(index)
    case index
    when 0...0.3 then 'Bajo'
    when 0.3...0.5 then 'Moderado'
    when 0.5...0.7 then 'Alto'
    else 'Muy Alto'
    end
  end

  # Format confidence percentage
  def format_confidence(confidence)
    "#{(confidence * 100).round(0)}%"
  end

  # Format growth percentage with sign
  def format_growth(growth)
    growth >= 0 ? "+#{growth}%" : "#{growth}%"
  end
end


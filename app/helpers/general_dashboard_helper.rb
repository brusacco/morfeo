# frozen_string_literal: true

module GeneralDashboardHelper
  # Sentiment visualization helpers
  def sentiment_emoji(score)
    case score
    when 50..Float::INFINITY
      '😄'
    when 10..50
      '🙂'
    when -10..10
      '😐'
    when -50..-10
      '☹️'
    else
      '😠'
    end
  end

  def sentiment_score_color(score)
    case score
    when 50..Float::INFINITY
      'text-green-700'
    when 10..50
      'text-green-600'
    when -10..10
      'text-gray-600'
    when -50..-10
      'text-red-600'
    else
      'text-red-700'
    end
  end

  def sentiment_trend_icon(direction)
    case direction
    when 'up'
      '<i class="fa-solid fa-arrow-up text-green-600"></i>'.html_safe
    when 'down'
      '<i class="fa-solid fa-arrow-down text-red-600"></i>'.html_safe
    else
      '<i class="fa-solid fa-minus text-gray-600"></i>'.html_safe
    end
  end

  # Chart data preparation
  def prepare_sentiment_pie_data(distribution)
    return {} unless distribution.is_a?(Hash)
    
    data = {}
    distribution.each do |key, value|
      label = case key
              when :very_positive then 'Muy Positivo'
              when :positive then 'Positivo'
              when :neutral then 'Neutral'
              when :negative then 'Negativo'
              when :very_negative then 'Muy Negativo'
              else key.to_s.titleize
              end
      
      count = value.is_a?(Hash) ? value[:count] : value
      data[label] = count
    end
    data
  end

  def prepare_reaction_breakdown(breakdown)
    return {} unless breakdown.is_a?(Hash)
    
    {
      '❤️ Love' => breakdown[:love],
      '😂 Haha' => breakdown[:haha],
      '😮 Wow' => breakdown[:wow],
      '👍 Like' => breakdown[:like],
      '🙏 Thankful' => breakdown[:thankful],
      '😢 Sad' => breakdown[:sad],
      '😡 Angry' => breakdown[:angry]
    }.compact
  end

  # Polarity helpers (reuse from existing helpers)
  def polarity_percentages(hash)
    total = hash.values.sum
    return {} if total.zero?
    
    result = {}
    hash.each do |key, value|
      label = case key
              when 'negative', :negative then 'Negativas'
              when 'neutral', :neutral then 'Neutras'
              when 'positive', :positive then 'Positivas'
              else key.to_s.titleize
              end
      result[label] = ((value.to_f / total) * 100).round(1)
    end
    result
  end

  def share_of_voice_percentage(part, whole)
    return 0 if whole.nil? || whole.zero?
    ((part.to_f / whole) * 100).round(1)
  end

  # Data confidence indicators
  def data_confidence_badge(confidence_level)
    case confidence_level
    when 0.9..1.0
      '<span class="inline-flex items-center px-2 py-1 rounded text-xs font-medium bg-green-100 text-green-800">
        <i class="fa-solid fa-check-circle mr-1"></i> Alta confianza
      </span>'.html_safe
    when 0.7..0.9
      '<span class="inline-flex items-center px-2 py-1 rounded text-xs font-medium bg-blue-100 text-blue-800">
        <i class="fa-solid fa-info-circle mr-1"></i> Confianza moderada
      </span>'.html_safe
    when 0.5..0.7
      '<span class="inline-flex items-center px-2 py-1 rounded text-xs font-medium bg-yellow-100 text-yellow-800">
        <i class="fa-solid fa-exclamation-triangle mr-1"></i> Estimado
      </span>'.html_safe
    else
      '<span class="inline-flex items-center px-2 py-1 rounded text-xs font-medium bg-red-100 text-red-800">
        <i class="fa-solid fa-times-circle mr-1"></i> Baja confianza
      </span>'.html_safe
    end
  end

  def metric_confidence(metric_name)
    case metric_name
    when :mentions then 1.0        # Direct counts - 100% accurate
    when :interactions then 1.0    # Direct counts - 100% accurate
    when :facebook_reach then 0.95 # Meta API views - very reliable
    when :digital_reach then 0.6   # Estimated (3x multiplier) - moderate confidence
    when :twitter_reach then 0.90  # Twitter API views - very reliable (when available)
    when :sentiment then 0.85      # AI-based - good confidence
    when :share_of_voice then 0.95 # Calculated - very reliable
    else 0.7                       # Default moderate
    end
  end
end


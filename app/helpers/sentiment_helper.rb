# frozen_string_literal: true

module SentimentHelper
  def sentiment_emoji(score)
    return '❓' if score.nil?
    
    case score
    when 1.5..Float::INFINITY
      '😊'
    when 0.5..1.5
      '🙂'
    when -0.5..0.5
      '😐'
    when -1.5..-0.5
      '☹️'
    else
      '😠'
    end
  end
  
  def sentiment_score_color(score)
    return 'text-gray-600' if score.nil?
    
    case score
    when 1.5..Float::INFINITY
      'text-green-700'
    when 0.5..1.5
      'text-green-600'
    when -0.5..0.5
      'text-gray-600'
    when -1.5..-0.5
      'text-red-600'
    else
      'text-red-700'
    end
  end
  
  def sentiment_bg_color(score)
    return 'bg-gray-50' if score.nil?
    
    case score
    when 1.5..Float::INFINITY
      'bg-green-100'
    when 0.5..1.5
      'bg-green-50'
    when -0.5..0.5
      'bg-gray-50'
    when -1.5..-0.5
      'bg-red-50'
    else
      'bg-red-100'
    end
  end
  
  def prepare_sentiment_pie_data(distribution)
    return {} if distribution.nil? || distribution.empty?
    
    {
      'Muy Positivo' => distribution[:very_positive][:count],
      'Positivo' => distribution[:positive][:count],
      'Neutral' => distribution[:neutral][:count],
      'Negativo' => distribution[:negative][:count],
      'Muy Negativo' => distribution[:very_negative][:count]
    }
  end
  
  def prepare_reaction_breakdown(breakdown)
    return {} if breakdown.nil? || breakdown.empty?
    
    {
      'Love ❤️' => breakdown[:love],
      'Haha 😂' => breakdown[:haha],
      'Wow 😮' => breakdown[:wow],
      'Like 👍' => breakdown[:like],
      'Thankful 🙏' => breakdown[:thankful],
      'Sad 😢' => breakdown[:sad],
      'Angry 😡' => breakdown[:angry]
    }
  end
  
  def sentiment_trend_icon(direction)
    case direction
    when 'up'
      '<i class="fa-solid fa-arrow-trend-up"></i>'.html_safe
    when 'down'
      '<i class="fa-solid fa-arrow-trend-down"></i>'.html_safe
    else
      '<i class="fa-solid fa-minus"></i>'.html_safe
    end
  end
  
  def sentiment_trend_color(direction)
    case direction
    when 'up'
      'text-green-600 bg-green-100'
    when 'down'
      'text-red-600 bg-red-100'
    else
      'text-gray-600 bg-gray-100'
    end
  end
end


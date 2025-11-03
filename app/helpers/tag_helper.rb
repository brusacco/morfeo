# frozen_string_literal: true

module TagHelper
  include ActsAsTaggableOn::TagsHelper

  def polarity_percentages(data)
    total = Float(data.values.sum)
    return {} if total.zero?

    data.transform_values { |count| (count / total * 100).round(0) }
  end

  # Returns polarity data with Spanish labels in correct order for pie charts
  # This ensures colors always match correctly regardless of which sentiments are present
  def polarity_pie_data(data)
    total = Float(data.values.sum)
    return {} if total.zero?

    # Always return in this order: Positivas, Neutras, Negativas
    # This ensures the colors array [Green, Grey, Red] always matches correctly
    result = {}
    result['Positivas'] = ((data['positive'] || 0).to_f / total * 100).round(0) if data.key?('positive') && data['positive']&.positive?
    result['Neutras'] = ((data['neutral'] || 0).to_f / total * 100).round(0) if data.key?('neutral') && data['neutral']&.positive?
    result['Negativas'] = ((data['negative'] || 0).to_f / total * 100).round(0) if data.key?('negative') && data['negative']&.positive?
    
    result
  end

  # Returns polarity stacked chart data with Spanish labels in correct order
  # For multi-series charts grouped by polarity and date
  # This ensures colors always match correctly: Green (Positivas), Grey (Neutras), Red (Negativas)
  def polarity_stacked_chart_data(grouped_data)
    return {} if grouped_data.blank?
    
    first_key = grouped_data.keys.first
    
    if first_key.is_a?(Array)
      # Array-key format for Chartkick: {['series', date] => value}
      # Replace English polarity names with Spanish and maintain format
      result = {}
      
      grouped_data.each do |(polarity, date), value|
        # Handle both string and symbol polarity values
        polarity_str = polarity.to_s
        label = case polarity_str
                when 'positive' then 'Positivas'
                when 'neutral' then 'Neutras'
                when 'negative' then 'Negativas'
                else polarity_str
                end
        
        result[[label, date]] = value
      end
      
      # Sort to ensure correct order: Positivas first, then Neutras, then Negativas
      # This ensures the color mapping is consistent
      result.sort_by { |(label, date), _value| 
        sort_order = { 'Positivas' => 0, 'Neutras' => 1, 'Negativas' => 2 }
        [sort_order[label] || 999, date]
      }.to_h
    else
      # Hash format: {'positive' => {date => value}}
      ordered_result = {}
      ordered_result['Positivas'] = grouped_data['positive'] if grouped_data.key?('positive')
      ordered_result['Neutras'] = grouped_data['neutral'] if grouped_data.key?('neutral')
      ordered_result['Negativas'] = grouped_data['negative'] if grouped_data.key?('negative')
      ordered_result
    end
  end

  def prepare_word_cloud_data(word_occurrences, positive_words, negative_words)
    return [] if word_occurrences.blank?

    min_max = find_max_and_min_occurrences(word_occurrences)

    word_occurrences.shuffle { |a, b| a[1] <=> b[1] }
                    .map do |word, value|
      {
        word: word,
        color: word_color(positive_words, negative_words, word),
        weight: normalize_to_scale(value, min_max[:max], min_max[:min])
      }
    end
  end
end

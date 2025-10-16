# frozen_string_literal: true

module TopicHelper
  def polarity_percentages(data)
    total = Float(data.values.sum)
    return {} if total.zero?

    data.transform_values { |count| (count / total * 100).round(0) }
  end

  def share_of_voice_percentage(topic_value, total_value)
    total = Float(topic_value + total_value)
    return 0.0 if total.zero?

    (topic_value / total * 100).round(1)
  end
end

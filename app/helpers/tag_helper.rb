# frozen_string_literal: true

module TagHelper
  include ActsAsTaggableOn::TagsHelper

  def polarity_percentages(data)
    total = Float(data.values.sum)
    return {} if total.zero?

    data.transform_values { |count| (count / total * 100).round(0) }
  end

  def prepare_word_cloud_data(word_occurrences, positive_words, negative_words)
    return [] if word_occurrences.blank?

    min_max = find_max_and_min_occurrences(word_occurrences)

    word_occurrences.shuffle { |a, b| a[1] <=> b[1] }.map do |word, value|
      {
        word: word,
        color: word_color(positive_words, negative_words, word),
        weight: normalize_to_scale(value, min_max[:max], min_max[:min])
      }
    end
  end
end

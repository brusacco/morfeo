# frozen_string_literal: true

module TagHelper
  include ActsAsTaggableOn::TagsHelper

  def polarity_percentages(data)
    total = Float(data.values.sum)
    return {} if total.zero?

    data.transform_values { |count| (count / total * 100).round(0) }
  end
end

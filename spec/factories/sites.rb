# frozen_string_literal: true

FactoryBot.define do
  factory :site do
    sequence(:name) { |n| "Site #{n}" }
    sequence(:url) { |n| "https://example#{n}.com" }
    status { true }
    is_js { false }
  end
end

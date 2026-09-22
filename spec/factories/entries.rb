# frozen_string_literal: true

FactoryBot.define do
  factory :entry do
    association :site
    sequence(:title) { |n| "Entry #{n}" }
    sequence(:url) { |n| "https://entry#{n}.test" }
    published_at { Time.current }
    enabled { true }
    total_count { 0 }
    polarity { :neutral }
  end
end
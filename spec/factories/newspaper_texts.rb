# frozen_string_literal: true

FactoryBot.define do
  factory :newspaper_text do
    association :newspaper
    sequence(:title) { |n| "Headline #{n}" }
    description { Faker::Lorem.sentence }
  end
end

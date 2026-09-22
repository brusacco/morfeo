# frozen_string_literal: true

FactoryBot.define do
  factory :comment do
    association :entry
    sequence(:uid) { |n| "comment-#{n}" }
    message { Faker::Lorem.sentence }
    created_time { Time.current }
  end
end
# frozen_string_literal: true

FactoryBot.define do
  factory :report do
    association :topic
    report_text { Faker::Lorem.paragraph }
  end
end

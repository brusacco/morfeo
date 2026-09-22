# frozen_string_literal: true

FactoryBot.define do
  factory :page do
    association :site
    sequence(:uid) { |n| "page-#{n}" }
    name { Faker::Company.name }
    username { Faker::Internet.username }
    picture { Faker::Internet.url }
    followers { 0 }
  end
end

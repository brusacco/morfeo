# frozen_string_literal: true

FactoryBot.define do
  factory :template do
    association :topic
    association :admin_user
    title { Faker::Lorem.words(number: 3).join(' ') }
    sumary { Faker::Lorem.paragraph }
    start_date { Date.current - 7 }
    end_date { Date.current }
  end
end

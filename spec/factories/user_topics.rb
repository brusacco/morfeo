# frozen_string_literal: true

FactoryBot.define do
  factory :user_topic do
    association :user
    association :topic
  end
end
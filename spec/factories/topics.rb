# frozen_string_literal: true

FactoryBot.define do
  factory :topic do
    sequence(:name) { |n| "Topic #{n}" }
    status { true }
  end
end
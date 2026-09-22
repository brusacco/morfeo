# frozen_string_literal: true

FactoryBot.define do
  factory :newspaper do
    association :site
    date { Date.current }
  end
end

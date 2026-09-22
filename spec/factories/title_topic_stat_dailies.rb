# frozen_string_literal: true

FactoryBot.define do
  factory :title_topic_stat_daily do
    association :topic
    topic_date { Date.current }
    entry_quantity { 1 }
    entry_interaction { 10 }
    average { 10 }
  end
end

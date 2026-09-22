# frozen_string_literal: true

FactoryBot.define do
  factory :topic_stat_daily do
    association :topic
    topic_date { Date.current }
    entry_count { 1 }
    total_count { 10 }
    average { 10 }
    positive_quantity { 1 }
    negative_quantity { 0 }
    neutral_quantity { 0 }
    positive_interaction { 10 }
    negative_interaction { 0 }
    neutral_interaction { 0 }
  end
end

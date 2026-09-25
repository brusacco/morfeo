# frozen_string_literal: true

require 'rails_helper'

RSpec.describe HomeServices::CacheWarmerService do
  it 'warms each distinct active-topic set used by users' do
    first_user = create(:user)
    second_user = create(:user)
    third_user = create(:user)
    first_topic = create(:topic)
    second_topic = create(:topic)
    inactive_topic = create(:topic, status: false)
    create(:user_topic, user: first_user, topic: first_topic)
    create(:user_topic, user: first_user, topic: second_topic)
    create(:user_topic, user: second_user, topic: second_topic)
    create(:user_topic, user: second_user, topic: first_topic)
    create(:user_topic, user: third_user, topic: inactive_topic)

    warmed_sets = []
    allow(HomeServices::DashboardAggregatorService).to receive(:call) do |topics:, days_range:|
      warmed_sets << [topics.pluck(:id).sort, days_range]
      {}
    end

    results = described_class.call(days_range: 7)

    expect(warmed_sets).to contain_exactly([[first_topic.id, second_topic.id], 7], [[], 7])
    expect(results).to all(include(success: true))
  end
end

# frozen_string_literal: true

require 'rails_helper'

RSpec.describe HomeServices::DashboardAggregatorService do
  let(:topics) { create_list(:topic, 2) }
  let(:service) { described_class.new(topics: Topic.where(id: topics.map(&:id)), days_range: 7) }

  describe '#load_topic_stats_batch' do
    it 'loads current topic stats once per service instance' do
      create(:topic_stat_daily, topic: topics.first, topic_date: Date.current)

      expect(TopicStatDaily).to receive(:where).once.and_call_original

      first_result = service.send(:load_topic_stats_batch)
      second_result = service.send(:load_topic_stats_batch)

      expect(second_result).to equal(first_result)
    end
  end

  describe '#calculate_daily_topic_rankings' do
    it 'returns separate 24-hour rankings for interactions and entries' do
      create(:topic_stat_daily, topic: topics.first, topic_date: Date.current, entry_count: 8, total_count: 20)
      create(:topic_stat_daily, topic: topics.second, topic_date: Date.current, entry_count: 3, total_count: 50)
      create(:topic_stat_daily, topic: topics.first, topic_date: 2.days.ago.to_date, entry_count: 100, total_count: 1000)

      rankings = service.send(:calculate_daily_topic_rankings)

      expect(rankings[:interactions]).to eq(topics.second.name => 50, topics.first.name => 20)
      expect(rankings[:entries]).to eq(topics.first.name => 8, topics.second.name => 3)
    end
  end
end
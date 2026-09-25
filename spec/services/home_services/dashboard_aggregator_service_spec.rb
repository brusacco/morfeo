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
      create(
        :topic_stat_daily,
        topic: topics.first,
        topic_date: 2.days.ago.to_date,
        entry_count: 100,
        total_count: 1000
      )

      rankings = service.send(:calculate_daily_topic_rankings)

      expect(rankings[:interactions]).to eq(topics.second.name => 50, topics.first.name => 20)
      expect(rankings[:entries]).to eq(topics.first.name => 8, topics.second.name => 3)
    end
  end

  describe '#digital_channel_stats' do
    it 'counts only content-tagged entries' do
      topic = topics.first
      content_entry = create(:entry, total_count: 20, published_at: Time.current)
      content_entry.tag_list = ['alpha']
      content_entry.save!

      second_content_entry = create(:entry, total_count: 20, published_at: Time.current)
      second_content_entry.tag_list = ['alpha']
      second_content_entry.save!

      title_entry = create(:entry, total_count: 50, published_at: Time.current)
      title_entry.title_tag_list = ['alpha']
      title_entry.save!

      topic.tags << Tag.find_by!(name: 'alpha')

      stats = service.send(:digital_channel_stats)

      expect(stats[:mentions]).to eq(2)
      expect(stats[:interactions]).to eq(40)
    end
  end

  describe 'digital content tag filtering' do
    it 'excludes title-only tags from sentiment and previous interactions' do
      topic = topics.first
      content_entry = create(:entry, polarity: :positive, total_count: 20, published_at: 2.days.ago)
      content_entry.tag_list = ['alpha']
      content_entry.save!

      title_entry = create(:entry, polarity: :negative, total_count: 50, published_at: 2.days.ago)
      title_entry.title_tag_list = ['alpha']
      title_entry.save!

      previous_content_entry = create(:entry, total_count: 15, published_at: 10.days.ago)
      previous_content_entry.tag_list = ['alpha']
      previous_content_entry.save!

      previous_title_entry = create(:entry, total_count: 60, published_at: 10.days.ago)
      previous_title_entry.title_tag_list = ['alpha']
      previous_title_entry.save!

      topic.tags << Tag.find_by!(name: 'alpha')

      expect(service.send(:calculate_digital_sentiment)).to eq(100.0)
      expect(service.send(:calculate_previous_period_interactions)).to eq(15)
    end
  end
end

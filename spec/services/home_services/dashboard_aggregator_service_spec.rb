# frozen_string_literal: true

require 'rails_helper'

RSpec.describe HomeServices::DashboardAggregatorService do
  let(:topics) { create_list(:topic, 2) }
  let(:service) { described_class.new(topics: Topic.where(id: topics.map(&:id)), days_range: 7) }

  describe '#cache_key' do
    it 'uses a v5 key with sorted topic IDs and an explicit date range' do
      topic_ids = topics.map(&:id).sort.join(',')
      start_date = service.instance_variable_get(:@start_date).to_date.iso8601
      end_date = service.instance_variable_get(:@end_date).to_date.iso8601

      expect(service.send(:cache_key)).to eq("home_dashboard:v5:topics:#{topic_ids}:payload:#{start_date}:#{end_date}")
    end

    it 'is stable for reordered or duplicate topic inputs' do
      reordered = described_class.new(topics: topics.reverse, days_range: 7)
      duplicated = described_class.new(topics: [topics.first, topics.second, topics.first], days_range: 7)

      expect(reordered.send(:cache_key)).to eq(service.send(:cache_key))
      expect(duplicated.send(:cache_key)).to eq(service.send(:cache_key))
    end

    it 'distinguishes ranges and supports an empty topic set' do
      longer_range = described_class.new(topics: Topic.where(id: topics.map(&:id)), days_range: 30)
      empty_topics = described_class.new(topics: Topic.none, days_range: 7)

      expect(longer_range.send(:cache_key)).not_to eq(service.send(:cache_key))
      expect(empty_topics.send(:cache_key)).to start_with('home_dashboard:v5:topics::payload:')
    end
  end

  describe '#call' do
    it 'returns cached Tags Cloud data without recalculating it' do
      cached_payload = { word_occurrences: [['morfeo', 12]] }
      allow(Rails.cache).to receive(:fetch).and_return(cached_payload)

      expect(service).not_to receive(:calculate_word_occurrences)

      expect(service.call).to eq(cached_payload)
    end

    it 'includes Tags Cloud data in a newly cached payload' do
      allow(Rails.cache).to receive(:fetch).and_yield
      allow(service).to receive_messages(
        calculate_executive_summary: {},
        calculate_channel_stats: {},
        calculate_topic_stats: {},
        calculate_topic_trends: {},
        calculate_topic_chart_series: {},
        calculate_daily_topic_rankings: {},
        generate_alerts: [],
        fetch_top_content: {},
        calculate_word_occurrences: [['morfeo', 12]],
        calculate_sentiment_intelligence: {},
        calculate_temporal_intelligence: {},
        calculate_competitive_intelligence: {}
      )

      expect(service.call).to include(word_occurrences: [['morfeo', 12]])
    end
  end

  describe '#load_topic_stats_batch' do
    it 'loads current topic stats once per service instance' do
      create(:topic_stat_daily, topic: topics.first, topic_date: Date.current)

      expect(TopicStatDaily).to receive(:where).once.and_call_original

      first_result = service.send(:load_topic_stats_batch)
      second_result = service.send(:load_topic_stats_batch)

      expect(second_result).to equal(first_result)
    end

    it 'keeps a topic relation in SQL instead of materializing topic IDs' do
      topic_scope = Topic.where(id: topics.map(&:id))
      scoped_service = described_class.new(topics: topic_scope, days_range: 7)

      expect(topic_scope).not_to receive(:map)

      scoped_service.send(:load_topic_stats_batch)
    end
  end

  describe '#tag_ids' do
    it 'loads distinct IDs for all topics with one tag query' do
      shared_tag = create(:tag)
      second_tag = create(:tag)
      topics.first.tags << shared_tag
      topics.second.tags << shared_tag << second_tag

      expect(Tag).to receive(:joins).with(:topics).once.and_call_original

      expect(service.send(:tag_ids)).to contain_exactly(shared_tag.id, second_tag.id)
      expect(service.send(:tag_ids)).to contain_exactly(shared_tag.id, second_tag.id)
    end
  end

  describe '#calculate_word_occurrences' do
    it 'delegates Tags Cloud analysis to the relation included in the cached payload' do
      entries = double('entries')
      occurrences = [['morfeo', 12]]
      allow(service).to receive(:word_occurrence_entries).and_return(entries)

      expect(entries).to receive(:word_occurrences).and_return(occurrences)

      expect(service.send(:calculate_word_occurrences)).to eq(occurrences)
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

  describe 'Instagram channel integration' do
    it 'includes Instagram in executive totals and channel comparison data' do
      allow(service).to receive_messages(
        digital_channel_stats: {
          mentions: 2,
          interactions: 4,
          reach: 12,
          engagement_rate: 33.33,
          trend: 0,
          sentiment: 10
        },
        facebook_channel_stats: {
          mentions: 3,
          interactions: 6,
          reach: 18,
          engagement_rate: 33.33,
          trend: 0,
          sentiment: 20
        },
        twitter_channel_stats: {
          mentions: 4,
          interactions: 8,
          reach: 24,
          engagement_rate: 33.33,
          trend: 0,
          sentiment: 0
        },
        instagram_channel_stats: {
          mentions: 5,
          interactions: 10,
          reach: 30,
          engagement_rate: 33.33,
          trend: 0,
          sentiment: 0
        },
        calculate_previous_period_interactions: 0
      )

      expect(service.send(:calculate_executive_summary)).to include(
        total_mentions: 14,
        total_interactions: 28,
        total_reach: 84
      )
      expect(service.send(:calculate_channel_stats).fetch(:instagram)).to include(
        name: 'Instagram',
        mentions: 5,
        interactions: 10,
        reach: 30
      )
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

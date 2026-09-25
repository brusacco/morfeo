# frozen_string_literal: true

require 'rails_helper'

RSpec.describe DigitalDashboardServices::AggregatorService do
  let(:tags_relation) { double('tags_relation', pluck: %w[alpha beta]) }
  let(:topic) { double('topic', id: 7, tags: tags_relation) }
  let(:service) { described_class.new(topic: topic) }

  before do
    allow(described_class).to receive(:new).and_return(service)
    allow(Rails.cache).to receive(:fetch) { |*_args, &block| block.call }
  end

  it 'returns the combined dashboard payload' do
    allow(service).to receive_messages(
      topic_data: { topic: 'data' },
      load_chart_data: { chart: 'data' },
      calculate_percentages: { percentage: 100 },
      load_tags_and_word_data: { words: %w[a b] },
      load_temporal_intelligence: { temporal: 'data' },
      detect_viral_content: [{ id: 1 }]
    )

    expect(described_class.call(topic: topic)).to eq(
      topic_data: { topic: 'data' },
      chart_data: { chart: 'data' },
      percentages: { percentage: 100 },
      tags_and_words: { words: %w[a b] },
      temporal_intelligence: { temporal: 'data' },
      viral_content: [{ id: 1 }]
    )
  end

  it 'combines entry and polarity aggregates in one query' do
    entries = double('entries')
    allow(entries).to receive(:reorder).with(nil).and_return(entries)
    expect(entries).to receive(:pick).once do |sql|
      expect(sql.to_s).to include('COUNT(entries.id)')
      expect(sql.to_s).to include('CASE WHEN entries.polarity = 0')
      expect(sql.to_s).to include('CASE WHEN entries.polarity = 1')
      expect(sql.to_s).to include('CASE WHEN entries.polarity = 2')

      [5, 150, 2, 30, 2, 100, 1, 20]
    end

    expect(service.send(:calculate_entry_aggregations, entries)).to eq(
      entries_count: 5,
      entries_total_sum: 150,
      entries_polarity_counts: { 'neutral' => 2, 'positive' => 2, 'negative' => 1 },
      entries_polarity_sums: { 'neutral' => 30, 'positive' => 100, 'negative' => 20 },
      total_entries: 5,
      total_interactions: 150
    )
  end

  it 'combines site counts and interaction sums in one query' do
    entries = double('entries')
    grouped_entries = double('grouped_entries')
    allow(entries).to receive(:reorder).with(nil).and_return(grouped_entries)
    allow(grouped_entries).to receive(:group).with('sites.id', 'sites.name').and_return(grouped_entries)
    expect(grouped_entries).to receive(:pluck).once do |*columns|
      expect(columns.map(&:to_s)).to eq(['sites.name', 'COUNT(entries.id)', 'COALESCE(SUM(entries.total_count), 0)'])

      [['Site A', 2, 100], ['Site A', 1, 25], ['Site B', 1, 10]]
    end

    expect(service.send(:calculate_site_data, entries)).to eq(
      site_counts: { 'Site A' => 3, 'Site B' => 1 },
      site_sums: { 'Site A' => 125, 'Site B' => 10 }
    )
  end

  it 'uses cached global stats for direct-entry share of voice' do
    entries = double('entries')
    ordered_entries = double('ordered_entries', limit: [])
    allow(service).to receive(:topic_data).and_return(
      entries: entries,
      entries_count: 3,
      entries_total_sum: 30,
      entries_polarity_counts: { 'neutral' => 1, 'positive' => 2 }
    )
    allow(service).to receive(:global_digital_stats).and_return(entries_count: 7, interactions: 70)
    allow(entries).to receive(:order).with(total_count: :desc).and_return(ordered_entries)
    allow(ENV).to receive(:[]).and_call_original
    allow(ENV).to receive(:[]).with('USE_DIRECT_ENTRY_TOPICS').and_return('true')
    expect(topic).not_to receive(:all_list_entries)

    expect(service.send(:calculate_percentages)).to include(
      topic_percentage: 30,
      all_percentage: 70,
      topic_interactions_percentage: 30.0,
      all_interactions_percentage: 70.0,
      all_entries_size: 7,
      all_entries_interactions: 70
    )
  end

  it 'aggregates global digital stats in one query' do
    date_range = { gte: 7.days.ago.beginning_of_day, lte: Time.current.end_of_day }
    entries = double('entries')
    allow(topic).to receive(:default_date_range).and_return(date_range)
    allow(Entry).to receive(:enabled).and_return(entries)
    allow(entries).to receive(:where).with(published_at: date_range[:gte]..date_range[:lte]).and_return(entries)
    allow(entries).to receive(:joins).with(:site).and_return(entries)
    allow(entries).to receive(:reorder).with(nil).and_return(entries)
    expect(entries).to receive(:pick).once do |count_sql, sum_sql|
      expect(count_sql.to_s).to eq('COUNT(entries.id)')
      expect(sum_sql.to_s).to eq('COALESCE(SUM(entries.total_count), 0)')

      [7, 70]
    end

    expect(service.send(:global_digital_stats)).to eq(entries_count: 7, interactions: 70)
  end
end

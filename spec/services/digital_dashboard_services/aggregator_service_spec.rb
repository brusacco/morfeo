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
end

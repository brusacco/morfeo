# frozen_string_literal: true

require 'rails_helper'

RSpec.describe GeneralDashboardServices::AggregatorService do
  let(:tags_relation) { double('tags_relation', pluck: %w[alpha beta]) }
  let(:topic) { double('topic', id: 7, tags: tags_relation) }
  let(:service) { described_class.new(topic: topic) }

  before do
    allow(described_class).to receive(:new).and_return(service)
    allow(Rails.cache).to receive(:fetch) { |*_args, &block| block.call }
  end

  it 'returns the combined dashboard payload' do
    allow(service).to receive_messages(
      build_executive_summary: { executive: 'summary' },
      build_channel_performance: { channels: 'data' },
      build_temporal_intelligence_lightweight: { temporal: 'data' },
      build_sentiment_analysis: { sentiment: 'data' },
      build_reach_analysis: { reach: 'data' },
      build_competitive_analysis: { competitive: 'data' },
      build_top_content: { top: 'data' },
      build_word_analysis_lightweight: { words: 'data' },
      build_recommendations: { recommendations: ['a'] }
    )

    expect(described_class.call(topic: topic)).to eq(
      executive_summary: { executive: 'summary' },
      channel_performance: { channels: 'data' },
      temporal_intelligence: { temporal: 'data' },
      sentiment_analysis: { sentiment: 'data' },
      reach_analysis: { reach: 'data' },
      competitive_analysis: { competitive: 'data' },
      top_content: { top: 'data' },
      word_analysis: { words: 'data' },
      recommendations: { recommendations: ['a'] }
    )
  end

  it 'loads current digital metrics with one aggregate query' do
    current_entries = double('current_entries')
    previous_entries = double('previous_entries')
    current_distinct_entries = double('current_distinct_entries')
    previous_distinct_entries = double('previous_distinct_entries')

    allow(topic).to receive(:report_entries).and_return(current_entries, previous_entries)
    allow(current_entries).to receive(:distinct).and_return(current_distinct_entries)
    allow(current_distinct_entries).to receive(:reorder).with(nil).and_return(current_distinct_entries)
    allow(previous_entries).to receive(:distinct).and_return(previous_distinct_entries)
    allow(previous_distinct_entries).to receive(:count).and_return(2)
    expect(current_distinct_entries).to receive(:pluck).once.and_return([[3, 12]])

    expect(service.send(:digital_data)).to eq(count: 3, interactions: 12, reach: 36, trend: 50.0)
  end
end

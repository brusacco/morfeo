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
end

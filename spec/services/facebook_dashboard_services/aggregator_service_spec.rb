# frozen_string_literal: true

require 'rails_helper'

RSpec.describe FacebookDashboardServices::AggregatorService do
  let(:tags_relation) { double('tags_relation', pluck: %w[alpha beta]) }
  let(:topic) { double('topic', id: 7, tags: tags_relation) }
  let(:service) { described_class.new(topic: topic) }

  before do
    allow(described_class).to receive(:new).and_return(service)
    allow(Rails.cache).to receive(:fetch) { |*args, &block| block.call }
  end

  it 'returns the combined dashboard payload' do
    allow(service).to receive_messages(
      facebook_data: { facebook: 'data' },
      load_pages_data: { pages: 'data' },
      load_temporal_intelligence: { temporal: 'data' },
      load_sentiment_analysis: { sentiment: 'data' },
      detect_viral_content: [{ id: 1 }]
    )

    expect(described_class.call(topic: topic)).to eq(
      facebook_data: { facebook: 'data' },
      pages_data: { pages: 'data' },
      temporal_intelligence: { temporal: 'data' },
      sentiment_analysis: { sentiment: 'data' },
      viral_content: [{ id: 1 }]
    )
  end
end
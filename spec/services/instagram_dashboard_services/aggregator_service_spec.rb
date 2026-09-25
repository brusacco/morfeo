# frozen_string_literal: true

require 'rails_helper'

RSpec.describe InstagramDashboardServices::AggregatorService do
  let(:tags_relation) { double('tags_relation', pluck: %w[alpha beta]) }
  let(:topic) { double('topic', id: 7, tags: tags_relation, positive_words: nil, negative_words: nil) }
  let(:service) { described_class.new(topic: topic) }

  before do
    allow(described_class).to receive(:new).and_return(service)
    allow(Rails.cache).to receive(:fetch) { |*_args, &block| block.call }
  end

  it 'returns the combined dashboard payload' do
    allow(service).to receive_messages(
      instagram_data: { instagram: 'data' },
      load_profiles_data: { profiles: 'data' },
      load_temporal_intelligence: { temporal: 'data' },
      detect_viral_content: [{ id: 1 }]
    )

    expect(described_class.call(topic: topic)).to eq(
      instagram_data: { instagram: 'data' },
      profiles_data: { profiles: 'data' },
      temporal_intelligence: { temporal: 'data' },
      viral_content: [{ id: 1 }]
    )
  end

  it 'reuses memoized tag names and combined text analysis for the dashboard posts' do
    posts = double('posts')
    text_analysis = { word_occurrences: [['alpha', 2]], bigram_occurrences: [['alpha beta', 2]] }

    allow(service).to receive_messages(calculate_chart_data: {}, calculate_statistics: {}, calculate_tag_data: {})
    expect(InstagramPost).to receive(:for_topic)
      .with(topic,
            start_time: service.instance_variable_get(:@start_time),
            end_time: service.instance_variable_get(:@end_time),
            tag_names: %w[
              alpha beta
            ])
      .and_return(posts)
    expect(InstagramPost).to receive(:text_occurrences).with(posts).and_return(text_analysis)

    result = service.send(:load_instagram_data)

    expect(result).to include(text_analysis)
  end
end

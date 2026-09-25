# frozen_string_literal: true

require 'rails_helper'

RSpec.describe InstagramDashboardServices::AggregatorService do
  let(:tags_relation) { double('tags_relation') }
  let(:topic) { double('topic', id: 7, tags: tags_relation, positive_words: nil, negative_words: nil) }
  let(:service) { described_class.new(topic: topic) }

  before do
    allow(tags_relation).to receive(:pluck).with(:id, :name).and_return([[1, 'alpha'], [2, 'beta']])
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

  it 'includes topic, limit, range, and date in its cache key' do
    expect(service.send(:cache_key)).to eq("instagram_dashboard_7_20_#{DAYS_RANGE}_#{Date.current}")
  end

  it 'returns empty dashboard data when the topic has no tags' do
    empty_topic = double('empty_topic', id: 8, tags: double('tags_relation', pluck: []))
    allow(described_class).to receive(:new).and_call_original
    empty_service = described_class.new(topic: empty_topic)

    expect(empty_service.send(:load_instagram_data)).to include(
      tag_list: [], total_posts: 0, total_interactions: 0, total_views: 0, average_interactions: 0, top_posts: []
    )
    expect(empty_service.send(:load_profiles_data)).to eq(
      profiles_count: [], profiles_interactions: [], site_top_counts: {}, site_counts: {}, site_sums: {}
    )
  end

  it 'calculates statistics safely for an empty result set' do
    posts = double('posts')
    aggregate_posts = double('aggregate_posts')
    allow(posts).to receive(:except).with(:includes).and_return(aggregate_posts)
    allow(aggregate_posts).to receive(:reorder).with(nil).and_return(aggregate_posts)
    allow(aggregate_posts).to receive(:pluck).and_return([])
    allow(posts).to receive(:reorder).and_return(posts)
    allow(posts).to receive(:limit).with(20).and_return([])

    expect(service.send(:calculate_statistics, posts)).to eq(
      total_posts: 0, total_interactions: 0, total_views: 0, average_interactions: 0, top_posts: []
    )
  end

  it 'calculates rounded average interactions and keeps the configured top-post limit' do
    posts = double('posts')
    aggregate_posts = double('aggregate_posts')
    top_posts = [double('post')]
    allow(posts).to receive(:except).with(:includes).and_return(aggregate_posts)
    allow(aggregate_posts).to receive(:reorder).with(nil).and_return(aggregate_posts)
    allow(aggregate_posts).to receive(:pluck).and_return([[3, 10, 40]])
    allow(posts).to receive(:reorder).and_return(posts)
    expect(posts).to receive(:limit).with(20).and_return(top_posts)

    expect(service.send(:calculate_statistics, posts)).to include(
      total_posts: 3, total_interactions: 10, total_views: 40, average_interactions: 3.3, top_posts: top_posts
    )
  end

  it 'falls back to safe temporal defaults when source methods fail' do
    %i[
      instagram_temporal_intelligence_summary
      instagram_optimal_publishing_time
      instagram_trend_velocity
      instagram_engagement_velocity
      instagram_content_half_life
      instagram_peak_publishing_times_by_hour
      instagram_peak_publishing_times_by_day
      instagram_engagement_heatmap_data
    ].each { |method_name| allow(topic).to receive(method_name).and_raise('unavailable') }

    expect(service.send(:load_temporal_intelligence)).to eq(
      temporal_summary: nil,
      optimal_time: nil,
      trend_velocity: { velocity_percent: 0, direction: 'stable' },
      engagement_velocity: { velocity_percent: 0, direction: 'stable' },
      content_half_life: nil,
      peak_hours: {},
      peak_days: {},
      heatmap_data: []
    )
  end

  it 'parses configured word lists and calculates odd and even medians' do
    expect(service.send(:parse_word_list, ' positivo, neutral ,negativo ')).to eq(%w[positivo neutral negativo])
    expect(service.send(:parse_word_list, nil)).to eq([])
    expect(service.send(:calculate_median, [1, 4, 9])).to eq(4.0)
    expect(service.send(:calculate_median, [1, 4, 9, 12])).to eq(6.5)
  end

  it 'reuses memoized tag names and combined text analysis for the dashboard posts' do
    posts = double('posts')
    text_analysis = { word_occurrences: [['alpha', 2]], bigram_occurrences: [['alpha beta', 2]] }

    allow(service).to receive_messages(calculate_chart_data: {}, calculate_statistics: {}, calculate_tag_data: {})
    expect(InstagramPost).to receive(:for_topic)
      .with(topic,
            start_time: service.instance_variable_get(:@start_time),
            end_time: service.instance_variable_get(:@end_time),
            tag_ids: [1, 2])
      .and_return(posts)
    expect(InstagramPost).to receive(:text_occurrences).with(posts).and_return(text_analysis)

    result = service.send(:load_instagram_data)

    expect(result).to include(text_analysis)
  end
end

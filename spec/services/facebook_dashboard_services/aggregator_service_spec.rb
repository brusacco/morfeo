# frozen_string_literal: true

require 'rails_helper'

RSpec.describe FacebookDashboardServices::AggregatorService do
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
      facebook_data: { facebook: 'data' },
      load_pages_data: { pages: 'data' },
      load_temporal_intelligence: { temporal: 'data' },
      load_sentiment_analysis: { sentiment: 'data' },
      detect_viral_content: [{ id: 1 }]
    )

    result = described_class.call(topic: topic)

    expect(result.except(:facebook_data)).to eq(
      pages_data: { pages: 'data' },
      temporal_intelligence: { temporal: 'data' },
      sentiment_analysis: { sentiment: 'data' },
      viral_content: [{ id: 1 }]
    )
    expect(result[:facebook_data]).to include(:facebook, :entries, :top_posts)
    expect(result[:facebook_data][:facebook]).to eq('data')
  end

  it 'keeps KPI scalars in the cached snapshot and attaches post relations afterwards' do
    posts = double('posts')
    top_posts = [double('post')]
    snapshot = {
      facebook_data: { total_posts: 3, total_interactions: 10, total_views: 40, average_interactions: 3.3 },
      pages_data: {},
      temporal_intelligence: {},
      sentiment_analysis: {},
      viral_content: []
    }

    allow(service).to receive(:facebook_data).and_return(
      snapshot[:facebook_data].merge(entries: :cached_relation, top_posts: :cached_top_posts)
    )
    allow(service).to receive_messages(
      load_pages_data: {},
      load_temporal_intelligence: {},
      load_sentiment_analysis: {},
      detect_viral_content: [],
      facebook_entries: posts
    )
    allow(service).to receive(:top_posts).with(posts).and_return(top_posts)

    expect(service.send(:build_dashboard_snapshot)).to eq(snapshot)

    result = service.send(:attach_post_relations, snapshot)

    expect(result[:facebook_data]).to include(entries: posts, top_posts: top_posts)
    expect(result[:facebook_data]).to include(snapshot[:facebook_data])
  end

  it 'uses a versioned cache key with topic and explicit date range' do
    start_date = service.instance_variable_get(:@start_time).to_date.iso8601
    end_date = service.instance_variable_get(:@end_time).to_date.iso8601

    expect(service.send(:cache_key)).to eq("facebook_dashboard:v5:topic:7:payload:#{start_date}:#{end_date}")
  end

  it 'shares cached snapshots across limits but not date ranges' do
    allow(described_class).to receive(:new).and_call_original
    short_range = described_class.new(topic: topic, top_posts_limit: 20, days_range: 7)
    long_range = described_class.new(topic: topic, top_posts_limit: 20, days_range: 30)
    larger_limit = described_class.new(topic: topic, top_posts_limit: 50, days_range: 7)

    expect(short_range.send(:cache_key)).not_to eq(long_range.send(:cache_key))
    expect(short_range.send(:cache_key)).to eq(larger_limit.send(:cache_key))
  end

  it 'reuses a cached snapshot while applying each requested top-post limit' do
    allow(described_class).to receive(:new).and_call_original
    short_limit = described_class.new(topic: topic, top_posts_limit: 20)
    large_limit = described_class.new(topic: topic, top_posts_limit: 50)
    posts = double('posts')
    snapshot = { facebook_data: { total_posts: 3 } }
    cached_snapshots = {}

    allow(Rails.cache).to receive(:fetch) do |key, **_options, &block|
      cached_snapshots.fetch(key) { cached_snapshots[key] = block.call }
    end
    expect(short_limit).to receive(:build_dashboard_snapshot).once.and_return(snapshot)
    expect(large_limit).not_to receive(:build_dashboard_snapshot)
    [short_limit, large_limit].each do |service_instance|
      allow(service_instance).to receive(:facebook_entries).and_return(posts)
    end
    allow(short_limit).to receive(:top_posts).with(posts).and_return([:short_limit_post])
    allow(large_limit).to receive(:top_posts).with(posts).and_return([:large_limit_post])

    expect(short_limit.call[:facebook_data]).to include(entries: posts, top_posts: [:short_limit_post])
    expect(large_limit.call[:facebook_data]).to include(entries: posts, top_posts: [:large_limit_post])
  end

  it 'returns empty dashboard data when the topic has no tags' do
    empty_topic = double('empty_topic', id: 8, tags: double('tags_relation', pluck: []))
    allow(described_class).to receive(:new).and_call_original
    empty_service = described_class.new(topic: empty_topic)

    expect(empty_service.send(:load_facebook_data)).to include(
      tag_list: [],
      total_posts: 0,
      total_interactions: 0,
      total_views: 0,
      average_interactions: 0,
      top_posts: []
    )
    expect(empty_service.send(:load_pages_data)).to eq(
      pages_count: [],
      pages_interactions: [],
      site_top_counts: {},
      site_counts: {},
      site_sums: {}
    )
  end

  it 'calculates statistics safely for an empty result set' do
    posts = double('posts')
    aggregate_posts = double('aggregate_posts')
    allow(posts).to receive(:except).with(:includes).and_return(aggregate_posts)
    allow(aggregate_posts).to receive(:reorder).with(nil).and_return(aggregate_posts)
    allow(aggregate_posts).to receive(:pluck).and_return([])

    expect(service.send(:calculate_statistics, posts)).to eq(
      total_posts: 0,
      total_interactions: 0,
      total_views: 0,
      average_interactions: 0
    )
  end

  it 'calculates rounded average interactions' do
    posts = double('posts')
    aggregate_posts = double('aggregate_posts')
    allow(posts).to receive(:except).with(:includes).and_return(aggregate_posts)
    allow(aggregate_posts).to receive(:reorder).with(nil).and_return(aggregate_posts)
    allow(aggregate_posts).to receive(:pluck).and_return([[3, 10, 40]])

    expect(service.send(:calculate_statistics, posts)).to include(
      total_posts: 3,
      total_interactions: 10,
      total_views: 40,
      average_interactions: 3.3
    )
  end

  it 'falls back to safe temporal defaults when source methods fail' do
    start_time = service.instance_variable_get(:@start_time)
    end_time = service.instance_variable_get(:@end_time)

    %i[
      facebook_optimal_publishing_time
      facebook_trend_velocity
      facebook_engagement_velocity
      facebook_content_half_life
      facebook_peak_publishing_times_by_hour
      facebook_peak_publishing_times_by_day
      facebook_engagement_heatmap_data
    ].each do |method_name|
      allow(topic).to receive(method_name).with(start_time: start_time, end_time: end_time).and_raise('unavailable')
    end

    expect(service.send(:load_temporal_intelligence)).to eq(
      temporal_summary: {
        optimal_time: nil,
        trend_velocity: { velocity_percent: 0, direction: 'stable' },
        engagement_velocity: { velocity_percent: 0, direction: 'stable' },
        content_half_life: nil,
        peak_hours: [],
        peak_days: []
      },
      optimal_time: nil,
      trend_velocity: { velocity_percent: 0, direction: 'stable' },
      engagement_velocity: { velocity_percent: 0, direction: 'stable' },
      content_half_life: nil,
      peak_hours: {},
      peak_days: {},
      heatmap_data: []
    )
  end

  it 'uses the dashboard date range for sentiment analysis' do
    sentiment_summary = { sentiment_distribution: { positive: 1 } }
    start_time = service.instance_variable_get(:@start_time)
    end_time = service.instance_variable_get(:@end_time)

    expect(topic).to receive(:facebook_sentiment_summary)
      .with(start_time: start_time, end_time: end_time)
      .and_return(sentiment_summary)
    allow(topic).to receive(:facebook_sentiment_trend).and_return({})

    expect(service.send(:load_sentiment_analysis)).to include(sentiment_summary: sentiment_summary)
  end

  it 'parses configured word lists and calculates odd and even medians' do
    expect(service.send(:parse_word_list, ' positivo, neutral ,negativo ')).to eq(%w[positivo neutral negativo])
    expect(service.send(:parse_word_list, nil)).to eq([])
    expect(service.send(:calculate_median, [1, 4, 9])).to eq(4.0)
    expect(service.send(:calculate_median, [1, 4, 9, 12])).to eq(6.5)
  end

  it 'reuses memoized tag names and combined text analysis for the dashboard entries' do
    entries = double('entries')
    text_analysis = { word_occurrences: [['alpha', 2]], bigram_occurrences: [['alpha beta', 2]] }

    allow(service).to receive_messages(calculate_chart_data: {}, calculate_statistics: {}, calculate_tag_data: {})
    expect(FacebookEntry).to receive(:for_topic)
      .with(topic,
            start_time: service.instance_variable_get(:@start_time),
            end_time: service.instance_variable_get(:@end_time),
            tag_ids: [1, 2])
      .and_return(entries)
    expect(FacebookEntry).to receive(:text_occurrences).with(entries).and_return(text_analysis)

    result = service.send(:load_facebook_data)

    expect(result).to include(text_analysis)
  end
end

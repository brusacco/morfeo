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

    result = described_class.call(topic: topic)

    expect(result.except(:instagram_data)).to eq(
      profiles_data: { profiles: 'data' },
      temporal_intelligence: { temporal: 'data' },
      viral_content: [{ id: 1 }]
    )
    expect(result[:instagram_data]).to include(:instagram, :posts, :top_posts)
    expect(result[:instagram_data][:instagram]).to eq('data')
  end

  it 'keeps KPI scalars in the cached snapshot and attaches post relations afterwards' do
    posts = double('posts')
    top_posts = [double('post')]
    snapshot = {
      instagram_data: { total_posts: 3, total_interactions: 10, total_views: 40, average_interactions: 3.3 },
      profiles_data: {},
      temporal_intelligence: {},
      viral_content: []
    }

    allow(service).to receive(:instagram_data).and_return(
      snapshot[:instagram_data].merge(posts: :cached_relation, top_posts: :cached_top_posts)
    )
    allow(service).to receive_messages(
      load_profiles_data: {},
      load_temporal_intelligence: {},
      detect_viral_content: [],
      instagram_posts: posts
    )
    allow(service).to receive(:top_posts).with(posts).and_return(top_posts)

    expect(service.send(:build_dashboard_snapshot)).to eq(snapshot)
    expect(
      service.send(
        :attach_post_relations,
        snapshot
      )[:instagram_data]
    ).to include(posts: posts, top_posts: top_posts)
  end

  it 'uses a versioned cache key with topic and explicit date range' do
    start_date = service.instance_variable_get(:@start_time).to_date.iso8601
    end_date = service.instance_variable_get(:@end_time).to_date.iso8601

    expect(service.send(:cache_key)).to eq("instagram_dashboard:v7:topic:7:payload:#{start_date}:#{end_date}")
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
    snapshot = { instagram_data: { total_posts: 3 } }
    cached_snapshots = {}

    allow(Rails.cache).to receive(:fetch) do |key, **_options, &block|
      cached_snapshots.fetch(key) { cached_snapshots[key] = block.call }
    end
    expect(short_limit).to receive(:build_dashboard_snapshot).once.and_return(snapshot)
    expect(large_limit).not_to receive(:build_dashboard_snapshot)
    [short_limit, large_limit].each do |service_instance|
      allow(service_instance).to receive(:instagram_posts).and_return(posts)
    end
    allow(short_limit).to receive(:top_posts).with(posts).and_return([:short_limit_post])
    allow(large_limit).to receive(:top_posts).with(posts).and_return([:large_limit_post])

    expect(short_limit.call[:instagram_data]).to include(posts: posts, top_posts: [:short_limit_post])
    expect(large_limit.call[:instagram_data]).to include(posts: posts, top_posts: [:large_limit_post])
  end

  it 'returns empty dashboard data when the topic has no tags' do
    empty_topic = double('empty_topic', id: 8, tags: double('tags_relation', pluck: []))
    allow(described_class).to receive(:new).and_call_original
    empty_service = described_class.new(topic: empty_topic)

    expect(empty_service.send(:load_instagram_data)).to include(
      tag_list: [], total_posts: 0, total_interactions: 0, total_views: nil, average_interactions: 0, top_posts: []
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

    expect(service.send(:calculate_statistics, posts)).to eq(
      total_posts: 0,
      total_interactions: 0,
      total_views: nil,
      views_estimated: false,
      views_source: :unavailable,
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
      views_estimated: false,
      views_source: :actual,
      average_interactions: 3.3
    )
  end

  it 'uses the observed video-view aggregate without an interaction fallback' do
    profile = InstagramProfile.create!(uid: SecureRandom.uuid, username: SecureRandom.hex(8))
    posts =
      [100, 200, nil, 300].map do |video_view_count|
        InstagramPost.create!(
          instagram_profile: profile,
          shortcode: SecureRandom.hex(8),
          posted_at: Time.current,
          likes_count: 0,
          comments_count: 0,
          video_view_count: video_view_count
        )
      end

    expect(service.send(:calculate_statistics, InstagramPost.where(id: posts))).to include(
      total_posts: 4,
      total_interactions: 0,
      total_views: 600,
      views_source: :actual
    )
  end

  it 'preserves provider-reported zero video views as observed' do
    posts = double('posts')
    aggregate_posts = double('aggregate_posts')
    allow(posts).to receive(:except).with(:includes).and_return(aggregate_posts)
    allow(aggregate_posts).to receive(:reorder).with(nil).and_return(aggregate_posts)
    allow(aggregate_posts).to receive(:pluck).and_return([[1, 10, 0]])

    expect(service.send(:calculate_statistics, posts)).to include(total_views: 0, views_source: :actual)
  end

  it 'leaves missing video views unavailable without estimating them' do
    posts = double('posts')
    aggregate_posts = double('aggregate_posts')
    allow(posts).to receive(:except).with(:includes).and_return(aggregate_posts)
    allow(aggregate_posts).to receive(:reorder).with(nil).and_return(aggregate_posts)
    allow(aggregate_posts).to receive(:pluck).and_return([[1, 10, nil]])

    expect(service.send(:calculate_statistics, posts)).to include(total_views: nil, views_source: :unavailable)
  end

  it 'falls back to safe temporal defaults when source methods fail' do
    start_time = service.instance_variable_get(:@start_time)
    end_time = service.instance_variable_get(:@end_time)

    %i[
      instagram_optimal_publishing_time
      instagram_trend_velocity
      instagram_engagement_velocity
      instagram_content_half_life
      instagram_peak_publishing_times_by_hour
      instagram_peak_publishing_times_by_day
      instagram_engagement_heatmap_data
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

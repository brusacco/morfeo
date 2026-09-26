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
      build_top_content_snapshot: { top: 'data' },
      build_word_analysis_lightweight: { words: 'data' },
      build_recommendations: { recommendations: ['a'] }
    )
    allow(service).to receive(:attach_content_relations) { |snapshot| snapshot }

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

  it 'caches only stable top content data' do
    allow(service).to receive(:trending_topics).and_return(%w[alpha beta])

    expect(service).not_to receive(:top_digital_entries)
    expect(service).not_to receive(:top_facebook_posts)
    expect(service).not_to receive(:top_tweets)
    expect(service).not_to receive(:identify_viral_content)

    expect(service.send(:build_top_content_snapshot)).to eq(trending_topics: %w[alpha beta])
  end

  it 'uses a v6 cache key for the selected reporting period' do
    start_date = Time.zone.parse('2026-09-01 10:00')
    end_date = Time.zone.parse('2026-09-15 22:00')
    allow(described_class).to receive(:new).and_call_original
    dated_service = described_class.new(topic: topic, start_date: start_date, end_date: end_date)

    expect(dated_service.send(:cache_key)).to eq('general_dashboard:v6:topic:7:payload:2026-09-01:2026-09-15')
  end

  it 'attaches top content relations after the cached snapshot is read' do
    snapshot = { top_content: { trending_topics: %w[alpha beta] } }
    viral_content = { digital: [], facebook: [], twitter: [] }
    allow(service).to receive_messages(
      top_digital_entries: [:digital_entry],
      top_facebook_posts: [:facebook_post],
      top_tweets: [:tweet],
      top_instagram_posts: [:instagram_post],
      identify_viral_content: viral_content
    )

    expect(service.send(:attach_content_relations, snapshot)[:top_content]).to eq(
      trending_topics: %w[alpha beta],
      top_entries: [:digital_entry],
      top_facebook_posts: [:facebook_post],
      top_tweets: [:tweet],
      top_instagram_posts: [:instagram_post],
      viral_content: viral_content
    )
  end

  it 'includes Instagram in channel metrics and cross-channel totals' do
    allow(service).to receive_messages(
      digital_data: { count: 2, interactions: 4, reach: 12, reach_estimated: true, trend: 1 },
      facebook_data: { count: 3, interactions: 6, reach: 18, reach_estimated: false, trend: 2 },
      twitter_data: { count: 4, interactions: 8, reach: 24, reach_estimated: false, trend: 3 },
      instagram_data: { count: 5, interactions: 10, reach: 30, reach_estimated: false, trend: 4 },
      digital_sentiment: { average: 0 },
      facebook_sentiment: { average: 0 },
      twitter_sentiment: { average: 0 },
      instagram_sentiment: { average: 0 }
    )

    expect(service.send(:total_mentions)).to eq(14)
    expect(service.send(:total_interactions)).to eq(28)
    expect(service.send(:total_reach)).to eq(84)
    expect(service.send(:build_channel_performance).fetch(:instagram)).to include(
      name: 'Instagram',
      mentions: 5,
      interactions: 10,
      reach: 30,
      reach_estimated: false,
      trend: 4
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

    expect(service.send(:digital_data)).to eq(
      count: 3, interactions: 12, reach: 36, reach_estimated: true, reach_source: :estimated, trend: 50.0
    )
  end

  it 'normalizes missing digital aggregates to zero' do
    current_entries = double('current_entries')
    previous_entries = double('previous_entries')
    current_distinct_entries = double('current_distinct_entries', reorder: nil)
    previous_distinct_entries = double('previous_distinct_entries', count: 0)
    allow(topic).to receive(:report_entries).and_return(current_entries, previous_entries)
    allow(current_entries).to receive(:distinct).and_return(current_distinct_entries)
    allow(current_distinct_entries).to receive(:reorder).with(nil).and_return(current_distinct_entries)
    allow(current_distinct_entries).to receive(:pluck).and_return([[0, nil]])
    allow(previous_entries).to receive(:distinct).and_return(previous_distinct_entries)

    expect(service.send(:digital_data)).to eq(
      count: 0, interactions: 0, reach: 0, reach_estimated: true, reach_source: :estimated, trend: 0
    )
  end

  it 'does not recommend a publishing time without temporal data' do
    allow(topic).to receive_messages(
      optimal_publishing_time: nil,
      facebook_optimal_publishing_time: nil,
      twitter_optimal_publishing_time: nil,
      instagram_optimal_publishing_time: nil
    )

    expect(service.send(:calculate_combined_optimal_time)).to be_nil
    expect(service.send(:best_publishing_time_recommendation)).to eq(
      recommendation: 'No hay datos suficientes para recomendar un horario de publicación.',
      reasoning: 'Se requieren datos de engagement por día y hora para generar esta recomendación.'
    )
  end

  it 'chooses the highest-engagement publishing time from all channels' do
    digital = { day: 'Martes', hour: 10, recommendation: 'Martes a las 10:00 hrs', avg_engagement: 4.0 }
    facebook = { day: 'Miércoles', hour: 15, recommendation: 'Miércoles a las 15:00 hrs', avg_engagement: 8.5 }
    twitter = { day: 'Jueves', hour: 12, recommendation: 'Jueves a las 12:00 hrs', avg_engagement: 6.0 }
    allow(topic).to receive_messages(
      optimal_publishing_time: digital,
      facebook_optimal_publishing_time: facebook,
      twitter_optimal_publishing_time: twitter,
      instagram_optimal_publishing_time: nil
    )

    expect(service.send(:calculate_combined_optimal_time)).to eq(facebook)
    expect(service.send(:best_publishing_time_recommendation)).to eq(
      recommendation: 'Miércoles a las 15:00 hrs',
      reasoning: 'Basado en análisis de engagement promedio más alto (8.5) en Miércoles a las 15:00'
    )
  end

  it 'marks multiplier-derived Twitter reach as estimated when views are unavailable' do
    current_scope = double('current_twitter_scope')
    previous_scope = double('previous_twitter_scope')
    allow(TwitterPost).to receive(:where).and_return(current_scope, previous_scope)
    allow(current_scope).to receive(:tagged_with).with(%w[alpha beta], any: true).and_return(current_scope)
    allow(current_scope).to receive(:pluck).and_return([[2, 5, 0]])
    allow(previous_scope).to receive(:tagged_with).with(%w[alpha beta], any: true).and_return(previous_scope)
    allow(previous_scope).to receive(:count).with('DISTINCT twitter_posts.id').and_return(1)

    expect(service.send(:twitter_data)).to eq(
      count: 2,
      interactions: 5,
      reach: 50,
      reach_estimated: true,
      reach_source: :fallback_estimate,
      trend: 100.0
    )
  end

  it 'keeps observed Twitter views distinct from estimated reach' do
    current_scope = double('current_twitter_scope')
    previous_scope = double('previous_twitter_scope')
    allow(TwitterPost).to receive(:where).and_return(current_scope, previous_scope)
    allow(current_scope).to receive(:tagged_with).with(%w[alpha beta], any: true).and_return(current_scope)
    allow(current_scope).to receive(:pluck).and_return([[2, 5, 40]])
    allow(previous_scope).to receive(:tagged_with).with(%w[alpha beta], any: true).and_return(previous_scope)
    allow(previous_scope).to receive(:count).with('DISTINCT twitter_posts.id').and_return(2)

    expect(service.send(:twitter_data)).to include(reach: 40, reach_estimated: false, trend: 0.0)
  end

  it 'returns zero social metrics without tags instead of querying social sources' do
    empty_topic = double('empty_topic', id: 8, tags: double('tags_relation', pluck: []))
    allow(described_class).to receive(:new).and_call_original
    empty_service = described_class.new(topic: empty_topic)

    expect(empty_service.send(:facebook_data)).to eq(
      count: 0,
      interactions: 0,
      reach: 0,
      reach_estimated: true,
      reach_source: :estimated,
      trend: 0
    )
    expect(empty_service.send(:twitter_data)).to eq(
      count: 0,
      interactions: 0,
      reach: 0,
      reach_estimated: false,
      reach_source: :actual,
      trend: 0
    )
  end

  describe 'Facebook trend velocity' do
    let(:persisted_topic) { create(:topic) }
    let(:first_tag) { create(:tag, name: 'alpha') }
    let(:second_tag) { create(:tag, name: 'beta') }
    let(:page) { create(:page) }

    before do
      allow_any_instance_of(Site).to receive(:save_image)
      persisted_topic.tags << [first_tag, second_tag]
      create_facebook_entry(posted_at: 2.hours.ago, tags: [first_tag, second_tag], emotional_intensity: 60)
      create_facebook_entry(posted_at: 26.hours.ago, tags: [first_tag], emotional_intensity: 10)
    end

    it 'uses valid ID counts for tagged Facebook entries from the General Dashboard path' do
      allow(described_class).to receive(:new).and_call_original
      allow(persisted_topic).to receive_messages(
        trend_velocity: { velocity_percent: 0 },
        twitter_trend_velocity: { velocity_percent: 0 }
      )
      persisted_service = described_class.new(topic: persisted_topic)
      count_queries = []
      subscriber =
        ActiveSupport::Notifications.subscribe('sql.active_record') do |_name, _started, _finished, _id, payload|
          count_queries << payload[:sql] if payload[:sql].include?('COUNT')
        end

      begin
        expect(persisted_service.send(:overall_trend_velocity)).to include(velocity_percent: 0.0)
        expect(persisted_topic.facebook_trend_velocity).to include(recent_count: 1, previous_count: 1)
      ensure
        ActiveSupport::Notifications.unsubscribe(subscriber)
      end

      facebook_count_queries = count_queries.grep(/facebook_entries/)
      expect(facebook_count_queries).to include(a_string_matching(/COUNT\((?:DISTINCT )?"facebook_entries"\."id"\)/))
      expect(facebook_count_queries).not_to include(a_string_matching(/COUNT\("facebook_entries"\.\*\)/))
    end

    it 'uses valid ID counts for tagged Facebook sentiment intensity aggregates' do
      allow(described_class).to receive(:new).and_call_original
      count_queries = []
      subscriber =
        ActiveSupport::Notifications.subscribe('sql.active_record') do |_name, _started, _finished, _id, payload|
          count_queries << payload[:sql] if payload[:sql].include?('COUNT')
        end

      begin
        summary = persisted_topic.facebook_sentiment_summary(start_time: 2.days.ago, end_time: Time.current)
        persisted_service = described_class.new(topic: persisted_topic)

        expect(summary[:emotional_trends]).to include(high_intensity_count: 1, low_intensity_count: 1)
        expect { persisted_service.send(:facebook_sentiment) }
          .not_to raise_error
      ensure
        ActiveSupport::Notifications.unsubscribe(subscriber)
      end

      facebook_count_queries = count_queries.grep(/facebook_entries/)
      expect(facebook_count_queries).to include(a_string_matching(/COUNT\((?:DISTINCT )?"facebook_entries"\."id"\)/))
      expect(facebook_count_queries).not_to include(a_string_matching(/COUNT\("facebook_entries"\.\*\)/))
    end

    it 'returns a safe stable velocity when no Facebook entries match the topic tags' do
      FacebookEntry.delete_all

      expect(persisted_topic.facebook_trend_velocity).to eq(velocity_percent: 0, direction: 'stable')
    end

    def create_facebook_entry(posted_at:, tags:, emotional_intensity: 0)
      entry = FacebookEntry.create!(
        page: page,
        facebook_post_id: SecureRandom.uuid,
        posted_at: posted_at,
        reactions_total_count: 10,
        tag_list: tags.map(&:name)
      )
      entry.update_column(:emotional_intensity, emotional_intensity)
      entry
    end
  end

  it 'preserves reach provenance in the reach analysis payload' do
    allow(service).to receive_messages(
      total_reach: 130,
      digital_data: { reach: 30, reach_estimated: true, reach_source: :estimated },
      facebook_data: { reach: 80, reach_estimated: true, reach_source: :estimated },
      twitter_data: { reach: 20, reach_estimated: true, reach_source: :fallback_estimate },
      instagram_data: { reach: 10, reach_estimated: false, reach_source: :actual },
      unique_sources_count: 4,
      geographic_distribution: {}
    )

    expect(service.send(:build_reach_analysis)).to include(
      total_reach: 130,
      by_channel: { digital: 30, facebook: 80, twitter: 20, instagram: 10 },
      estimated_channels: { digital: true, facebook: true, twitter: true, instagram: false },
      sources_by_channel: { digital: :estimated, facebook: :estimated, twitter: :fallback_estimate, instagram: :actual },
      total_reach_estimated: true
    )
  end

  it 'handles zero denominators in percentage calculations' do
    expect(service.send(:calculate_trend, 10, 0)).to eq(0)
    expect(service.send(:calculate_share, 10, 0)).to eq(0)
    expect(service.send(:calculate_engagement_rate, 10, 0)).to eq(0)
    expect(service.send(:calculate_trend, 15, 10)).to eq(50.0)
    expect(service.send(:calculate_share, 1, 3)).to eq(33.3)
    expect(service.send(:calculate_engagement_rate, 1, 3)).to eq(33.33)
  end

  it 'returns a neutral weighted sentiment when no channel has mentions' do
    allow(service).to receive_messages(
      digital_data: { count: 0 },
      facebook_data: { count: 0 },
      twitter_data: { count: 0 },
      digital_sentiment: { average: 80 },
      facebook_sentiment: { average: -80 },
      twitter_sentiment: { average: 10 }
    )

    expect(service.send(:average_sentiment)).to eq(0)
  end

  it 'combines string and integer digital polarities with Facebook sentiment counts' do
    allow(service).to receive_messages(
      digital_sentiment: { distribution: { positive: 3, neutral: 2, negative: 1 } },
      facebook_sentiment: {
        distribution: {
          very_positive: { count: 4 },
          positive: { count: 5 },
          neutral: { count: 6 },
          negative: { count: 7 },
          very_negative: { count: 8 }
        }
      }
    )

    expect(service.send(:combined_sentiment_distribution)).to eq(positive: 12, neutral: 8, negative: 16)
  end

  it 'assigns confidence at the documented sample-size boundaries' do
    expect(service).to receive(:total_mentions).and_return(0, 10, 50, 200, 1000)

    expect(Array.new(5) { service.send(:overall_sentiment_confidence) }).to eq([0.2, 0.5, 0.7, 0.85, 0.95])
  end

  it 'emits crisis and rapid-decline alerts together' do
    allow(service).to receive_messages(
      average_sentiment: -31,
      sentiment_trend: { change: -21, direction: 'declining' }
    )

    expect(service.send(:detect_sentiment_alerts)).to match_array(
      [
        hash_including(type: 'crisis', severity: 'high'),
        hash_including(type: 'warning', severity: 'medium')
      ]
    )
  end

  it 'emits an opportunity alert only for an improving positive trend' do
    allow(service).to receive_messages(average_sentiment: 51, sentiment_trend: { change: 5, direction: 'improving' })

    expect(service.send(:detect_sentiment_alerts)).to contain_exactly(
      hash_including(
        type: 'opportunity',
        severity: 'low'
      )
    )
  end

  it 'aggregates and ranks peak hours across channels' do
    allow(topic).to receive_messages(
      peak_publishing_times_by_hour: {
        9 => { avg_engagement: 3, entry_count: 2 },
        12 => { avg_engagement: 1, entry_count: 1 }
      },
      facebook_peak_publishing_times_by_hour: {
        9 => { avg_engagement: 4, entry_count: 1 },
        18 => { avg_engagement: 6, entry_count: 3 }
      },
      twitter_peak_publishing_times_by_hour: { 12 => { avg_engagement: 5, entry_count: 2 } },
      instagram_peak_publishing_times_by_hour: {}
    )

    expect(service.send(:combined_peak_hours)).to eq(
      9 => { avg_engagement: 7, entry_count: 3 },
      18 => { avg_engagement: 6, entry_count: 3 },
      12 => { avg_engagement: 6, entry_count: 3 }
    )
  end

  it 'aggregates and ranks peak days across channels' do
    allow(topic).to receive_messages(
      peak_publishing_times_by_day: { 1 => { avg_engagement: 2, entry_count: 1 } },
      facebook_peak_publishing_times_by_day: {
        1 => { avg_engagement: 3, entry_count: 2 },
        3 => { avg_engagement: 7, entry_count: 1 }
      },
      twitter_peak_publishing_times_by_day: { 5 => { avg_engagement: 4, entry_count: 2 } },
      instagram_peak_publishing_times_by_day: {}
    )

    expect(service.send(:combined_peak_days)).to eq(
      3 => { avg_engagement: 7, entry_count: 1 },
      1 => { avg_engagement: 5, entry_count: 3 },
      5 => { avg_engagement: 4, entry_count: 2 }
    )
  end

  it 'propagates the selected period to range-aware social temporal methods' do
    start_date = Time.zone.parse('2026-09-01 00:00')
    end_date = Time.zone.parse('2026-09-15 23:59')
    allow(described_class).to receive(:new).and_call_original
    dated_service = described_class.new(topic: topic, start_date: start_date, end_date: end_date)
    range = { start_time: start_date, end_time: end_date }

    allow(topic).to receive_messages(
      optimal_publishing_time: nil,
      peak_publishing_times_by_hour: {},
      peak_publishing_times_by_day: {},
      trend_velocity: { velocity_percent: 0 },
      engagement_velocity: { velocity_percent: 0 }
    )
    expect(topic).to receive(:facebook_optimal_publishing_time).with(**range).and_return(nil)
    expect(topic).to receive(:twitter_optimal_publishing_time).with(**range).and_return(nil)
    expect(topic).to receive(:instagram_optimal_publishing_time).with(**range).and_return(nil)
    expect(topic).to receive(:facebook_peak_publishing_times_by_hour).with(**range).and_return({})
    expect(topic).to receive(:twitter_peak_publishing_times_by_hour).with(**range).and_return({})
    expect(topic).to receive(:instagram_peak_publishing_times_by_hour).with(**range).and_return({})
    expect(topic).to receive(:facebook_peak_publishing_times_by_day).with(**range).and_return({})
    expect(topic).to receive(:twitter_peak_publishing_times_by_day).with(**range).and_return({})
    expect(topic).to receive(:instagram_peak_publishing_times_by_day).with(**range).and_return({})
    expect(topic).to receive(:facebook_trend_velocity).with(**range).and_return(velocity_percent: 0)
    expect(topic).to receive(:twitter_trend_velocity).with(**range).and_return(velocity_percent: 0)
    expect(topic).to receive(:instagram_trend_velocity).with(**range).and_return(velocity_percent: 0)
    expect(topic).to receive(:facebook_engagement_velocity).with(**range).and_return(velocity_percent: 0)
    expect(topic).to receive(:twitter_engagement_velocity).with(**range).and_return(velocity_percent: 0)
    expect(topic).to receive(:instagram_engagement_velocity).with(**range).and_return(velocity_percent: 0)

    dated_service.send(:calculate_combined_optimal_time)
    dated_service.send(:combined_peak_hours)
    dated_service.send(:combined_peak_days)
    dated_service.send(:overall_trend_velocity)
    dated_service.send(:overall_engagement_velocity)
  end

  it 'falls back to stable zero velocity when source velocity calls fail' do
    allow(topic).to receive_messages(
      trend_velocity: -> { raise 'unavailable' },
      facebook_trend_velocity: -> { raise 'unavailable' },
      twitter_trend_velocity: -> { raise 'unavailable' },
      instagram_trend_velocity: -> { raise 'unavailable' },
      engagement_velocity: -> { raise 'unavailable' },
      facebook_engagement_velocity: -> { raise 'unavailable' },
      twitter_engagement_velocity: -> { raise 'unavailable' },
      instagram_engagement_velocity: -> { raise 'unavailable' }
    )

    expect(service.send(:overall_trend_velocity)).to include(
      velocity_percent: 0.0,
      direction: 'stable',
      trend: 'estable'
    )
    expect(service.send(:overall_engagement_velocity)).to include(
      velocity_percent: 0.0,
      direction: 'stable',
      trend: 'moderado'
    )
  end

  it 'merges word occurrences and caps the result at the most frequent 100 words' do
    words = (1..101).map { |index| { "word#{index}" => index } }

    merged = service.send(:merge_word_occurrences, words)

    expect(merged).to have_attributes(size: 100)
    expect(merged.first).to eq(['word101', 101])
    expect(merged).not_to include(['word1', 1])
  end

  it 'returns hash-based combined text occurrences for recommendations' do
    digital_scope = double('digital_scope')
    facebook_scope = double('facebook_scope')
    twitter_scope = double('twitter_scope')
    digital_text = { word_occurrences: [['digital', 3]], bigram_occurrences: [['digital media', 2]] }
    facebook_text = { word_occurrences: [['facebook', 2]], bigram_occurrences: [] }
    twitter_text = { word_occurrences: [['twitter', 1]], bigram_occurrences: [] }

    allow(topic).to receive(:report_entries).with(service.start_date, service.end_date).and_return(digital_scope)
    allow(digital_scope).to receive(:text_occurrences).with(word_limit: 50, bigram_limit: 50).and_return(digital_text)
    allow(FacebookEntry).to receive(:for_topic).and_return(facebook_scope)
    allow(FacebookEntry).to receive(:text_occurrences).with(
      facebook_scope,
      word_limit: 50,
      bigram_limit: 50
    ).and_return(facebook_text)
    allow(TwitterPost).to receive(:for_topic).and_return(twitter_scope)
    allow(TwitterPost).to receive(:text_occurrences).with(
      twitter_scope,
      word_limit: 50,
      bigram_limit: 50
    ).and_return(twitter_text)

    expect(service.send(:combined_text_occurrences)).to eq(
      word_occurrences: [['digital', 3], ['facebook', 2], ['twitter', 1]],
      bigram_occurrences: [['digital media', 2]]
    )
  end

  it 'returns no growth opportunities when channel engagement is unavailable' do
    allow(service).to receive(:build_channel_performance).and_return(
      digital: { engagement_rate: nil },
      facebook: { engagement_rate: nil },
      twitter: { engagement_rate: nil }
    )

    expect(service.send(:growth_opportunities)).to eq([])
  end
end

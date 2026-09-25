# frozen_string_literal: true

require 'rails_helper'

RSpec.describe DigitalDashboardServices::AggregatorService do
  let(:tags_relation) do
    double('tags_relation').tap do |relation|
      allow(relation).to receive(:pluck).with(:id, :name).and_return([[1, 'alpha'], [2, 'beta']])
    end
  end
  let(:topic) { double('topic', id: 7, tags: tags_relation) }
  let(:service) { described_class.new(topic: topic) }

  def create_entry(polarity: nil, total_count: 0)
    Entry.create!(
      url: "https://example.test/entries/#{SecureRandom.uuid}",
      site: create(:site),
      published_at: Time.current,
      polarity: polarity,
      total_count: total_count
    )
  end

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
    expect(entries).to receive(:pick).once do |*columns|
      expect(columns.map(&:to_s)).to include(
        'COUNT(entries.id)',
        'COALESCE(SUM(entries.total_count), 0)',
        'COALESCE(SUM(CASE WHEN entries.polarity = 0 THEN 1 ELSE 0 END), 0)',
        'COALESCE(SUM(CASE WHEN entries.polarity = 1 THEN 1 ELSE 0 END), 0)',
        'COALESCE(SUM(CASE WHEN entries.polarity = 2 THEN 1 ELSE 0 END), 0)'
      )

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

  describe 'database-backed entry aggregations' do
    it 'returns zero-valued aggregates for an empty relation' do
      expect(service.send(:calculate_entry_aggregations, Entry.none)).to eq(
        entries_count: 0,
        entries_total_sum: 0,
        entries_polarity_counts: {},
        entries_polarity_sums: {},
        total_entries: 0,
        total_interactions: 0
      )
    end

    it 'ignores entries without a polarity in polarity aggregates' do
      entry = create_entry(total_count: 12)

      expect(service.send(:calculate_entry_aggregations, Entry.where(id: entry.id))).to include(
        entries_count: 1,
        entries_total_sum: 12,
        entries_polarity_counts: {},
        entries_polarity_sums: {}
      )
    end

    {
      neutral: ['neutral', 11],
      positive: ['positive', 13],
      negative: ['negative', 17]
    }.each do |polarity, (polarity_name, total_count)|
      it "aggregates only #{polarity} entries" do
        entry = create_entry(polarity: polarity, total_count: total_count)

        expect(service.send(:calculate_entry_aggregations, Entry.where(id: entry.id))).to include(
          entries_count: 1,
          entries_total_sum: total_count,
          entries_polarity_counts: { polarity_name => 1 },
          entries_polarity_sums: { polarity_name => total_count }
        )
      end
    end

    it 'aggregates mixed polarities in one result row' do
      entries = [
        create_entry(polarity: :neutral, total_count: 3),
        create_entry(polarity: :positive, total_count: 5),
        create_entry(polarity: :negative, total_count: 7)
      ]

      expect(service.send(:calculate_entry_aggregations, Entry.where(id: entries))).to include(
        entries_count: 3,
        entries_total_sum: 15,
        entries_polarity_counts: { 'neutral' => 1, 'positive' => 1, 'negative' => 1 },
        entries_polarity_sums: { 'neutral' => 3, 'positive' => 5, 'negative' => 7 }
      )
    end

    it 'treats NULL total_count as zero' do
      entry = create_entry(polarity: :neutral, total_count: nil)

      expect(service.send(:calculate_entry_aggregations, Entry.where(id: entry.id))).to include(
        entries_count: 1,
        entries_total_sum: 0,
        entries_polarity_counts: { 'neutral' => 1 },
        entries_polarity_sums: { 'neutral' => 0 }
      )
    end
  end

  describe 'tagged topics without matching entries' do
    def tagged_topic
      create(:topic).tap do |actual_topic|
        actual_topic.tags.create!(name: "empty-topic-#{SecureRandom.uuid}")
      end
    end

    it 'returns a complete dashboard for a topic with no entries or daily stats' do
      actual_topic = tagged_topic
      allow(described_class).to receive(:new).and_call_original

      payload = described_class.call(topic: actual_topic)

      expect(payload.fetch(:topic_data)).to include(
        entries_count: 0,
        entries_total_sum: 0,
        entries_polarity_counts: {},
        entries_polarity_sums: {},
        total_entries: 0,
        total_interactions: 0
      )
      expect(payload.fetch(:chart_data).fetch(:chart_entries_counts)).to eq({})
    end

    it 'preserves daily-stat chart data when a topic has no matching entries' do
      actual_topic = tagged_topic
      create(:topic_stat_daily, topic: actual_topic, entry_count: 4, total_count: 20)
      allow(described_class).to receive(:new).and_call_original

      payload = described_class.call(topic: actual_topic)

      expect(payload.fetch(:topic_data)).to include(entries_count: 0, entries_total_sum: 0)
      expect(payload.fetch(:chart_data).fetch(:chart_entries_counts)).to eq(Date.current => 4)
      expect(payload.fetch(:chart_data).fetch(:chart_entries_sums)).to eq(Date.current => 20)
    end
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

  it 'loads word and bigram occurrences together' do
    entries = double('entries')
    allow(topic).to receive_messages(positive_words: nil, negative_words: nil)
    expect(entries).to receive(:text_occurrences).once.with(word_limit: 100, bigram_limit: 100).and_return(
      word_occurrences: [['analysis', 3]],
      bigram_occurrences: [['data analysis', 2]]
    )

    expect(service.send(:load_text_analysis, entries)).to eq(
      word_occurrences: [['analysis', 3]],
      bigram_occurrences: [['data analysis', 2]],
      positive_words: [],
      negative_words: []
    )
  end

  it 'builds the temporal summary from metrics loaded once' do
    optimal_time = { day: 'Lunes', hour: 9, avg_engagement: 42.0, recommendation: 'Lunes a las 9:00 hrs' }
    trend_velocity = { velocity_percent: 10.0, direction: 'up' }
    engagement_velocity = { velocity_percent: 20.0, direction: 'up' }
    content_half_life = { median_hours: 18.0, average_hours: 18.0, sample_size: 2 }
    peak_hours = { 9 => { avg_engagement: 42.0, entry_count: 2 } }
    peak_days = { 'Lunes' => { avg_engagement: 42.0, entry_count: 2, day_number: 1 } }
    heatmap_data = [{ day: 'Lunes', day_number: 1, hour: 9, avg_engagement: 42.0, entry_count: 2 }]

    expect(topic).not_to receive(:temporal_intelligence_summary)
    expect(topic).to receive(:optimal_publishing_time).once.and_return(optimal_time)
    expect(topic).to receive(:trend_velocity).once.and_return(trend_velocity)
    expect(topic).to receive(:engagement_velocity).once.and_return(engagement_velocity)
    expect(topic).to receive(:content_half_life).once.and_return(content_half_life)
    expect(topic).to receive(:peak_publishing_times_by_hour).once.and_return(peak_hours)
    expect(topic).to receive(:peak_publishing_times_by_day).once.and_return(peak_days)
    expect(topic).to receive(:engagement_heatmap_data).once.and_return(heatmap_data)

    expect(service.send(:load_temporal_intelligence)).to eq(
      temporal_summary: {
        optimal_time: optimal_time,
        trend_velocity: trend_velocity,
        engagement_velocity: engagement_velocity,
        content_half_life: content_half_life,
        peak_hours: peak_hours.to_a,
        peak_days: peak_days.to_a
      },
      optimal_time: optimal_time,
      trend_velocity: trend_velocity,
      engagement_velocity: engagement_velocity,
      content_half_life: content_half_life,
      peak_hours: peak_hours,
      peak_days: peak_days,
      heatmap_data: heatmap_data
    )
  end

  it 'uses direct tag IDs to load recent viral entries' do
    recent_entries = double('recent_entries')
    allow(Entry).to receive(:enabled).and_return(recent_entries)
    allow(recent_entries).to receive(:where).with(published_at: kind_of(Range)).and_return(recent_entries)
    expect(recent_entries).to receive(:with_any_tag_ids).with([1, 2], context: :tags).and_return(recent_entries)
    allow(recent_entries).to receive(:includes).with(:site).and_return(recent_entries)
    allow(recent_entries).to receive(:to_a).and_return([])

    expect(service.send(:detect_viral_content)).to eq([])
  end
end

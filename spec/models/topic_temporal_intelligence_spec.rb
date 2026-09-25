# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Topic do
  subject(:topic) { described_class.new }

  let(:buckets) do
    [
      { day_number: 1, hour: 9, total_interactions: 100, entry_count: 1 },
      { day_number: 1, hour: 10, total_interactions: 20, entry_count: 4 },
      { day_number: 2, hour: 9, total_interactions: 30, entry_count: 2 }
    ]
  end

  before do
    allow(topic).to receive(:id).and_return(73)
    allow(Rails.cache).to receive(:fetch) { |*_args, &block| block.call }
  end

  describe 'temporal engagement metrics' do
    before do
      allow(topic).to receive(:temporal_hour_day_buckets).and_return(buckets)
    end

    it 'derives weighted hour, day, and heatmap results from the same buckets' do
      expect(topic.peak_publishing_times_by_hour).to eq(
        9 => { avg_engagement: 43.33, entry_count: 3 },
        10 => { avg_engagement: 5.0, entry_count: 4 }
      )
      expect(topic.peak_publishing_times_by_day).to eq(
        'Lunes' => { avg_engagement: 24.0, entry_count: 5, day_number: 1 },
        'Martes' => { avg_engagement: 15.0, entry_count: 2, day_number: 2 }
      )
      expect(topic.engagement_heatmap_data).to contain_exactly(
        { day: 'Lunes', day_number: 1, hour: 9, avg_engagement: 100.0, entry_count: 1 },
        { day: 'Lunes', day_number: 1, hour: 10, avg_engagement: 5.0, entry_count: 4 },
        { day: 'Martes', day_number: 2, hour: 9, avg_engagement: 15.0, entry_count: 2 }
      )
    end

    it 'returns empty temporal engagement data when no entries have interactions' do
      allow(topic).to receive(:temporal_hour_day_buckets).and_return([])

      expect(topic.peak_publishing_times_by_hour).to eq({})
      expect(topic.peak_publishing_times_by_day).to eq({})
      expect(topic.engagement_heatmap_data).to eq([])
      expect(topic.optimal_publishing_time).to be_nil
    end

    it 'preserves the optimal publishing-time shape' do
      expect(topic.optimal_publishing_time).to eq(
        day: 'Lunes',
        hour: 9,
        avg_engagement: 100.0,
        recommendation: 'Lunes a las 9:00 hrs'
      )
    end

    it 'loads all day and hour buckets with one SQL-side aggregate' do
      entries = double('entries')
      allow(topic).to receive(:temporal_hour_day_buckets).and_call_original
      allow(topic).to receive(:list_entries).and_return(entries)
      allow(entries).to receive(:reorder).with(nil).and_return(entries)
      allow(entries).to receive(:where).with('entries.total_count > 0').and_return(entries)
      allow(entries).to receive(:group)
        .with('DAYOFWEEK(entries.published_at)', 'HOUR(entries.published_at)')
        .and_return(entries)
      allow(entries).to receive(:order)
        .with('DAYOFWEEK(entries.published_at)', 'HOUR(entries.published_at)')
        .and_return(entries)
      expect(entries).to receive(:pluck).once do |*columns|
        expect(columns.map(&:to_s)).to include(
          'DAYOFWEEK(entries.published_at)',
          'HOUR(entries.published_at)',
          'COALESCE(SUM(entries.total_count), 0)',
          'COUNT(*)'
        )
        [[2, 9, 40, 2]]
      end

      expect(topic.__send__(:temporal_hour_day_buckets)).to eq(
        [{ day_number: 1, hour: 9, total_interactions: 40, entry_count: 2 }]
      )
    end
  end

  describe 'velocity metrics' do
    it 'derives trend and engagement velocity from one aggregate result' do
      allow(topic).to receive(:temporal_velocity_aggregates).and_return(
        recent_count: 6,
        previous_count: 3,
        recent_interactions: 120,
        previous_interactions: 60
      )

      expect(topic.trend_velocity).to include(velocity_percent: 100.0, trend: 'creciendo', direction: 'up')
      expect(topic.engagement_velocity).to include(velocity_percent: 100.0, trend: 'alto', direction: 'up')
    end

    it 'keeps zero-previous-period behavior' do
      allow(topic).to receive(:temporal_velocity_aggregates).and_return(
        recent_count: 2,
        previous_count: 0,
        recent_interactions: 15,
        previous_interactions: 0
      )

      expect(topic.trend_velocity).to eq(
        velocity_percent: 0,
        recent_count: 2,
        previous_count: 0,
        trend: 'estable',
        direction: 'stable'
      )
      expect(topic.engagement_velocity).to eq(
        velocity_percent: 0,
        recent_interactions: 15,
        previous_interactions: 0,
        trend: 'moderado',
        direction: 'stable'
      )
    end

    it 'loads all velocity inputs through one conditional aggregate query' do
      entries = double('entries')
      allow(topic).to receive(:list_entries).and_return(entries)
      allow(entries).to receive(:reorder).with(nil).and_return(entries)
      expect(entries).to receive(:pick).once do |sql|
        expect(sql.to_s).to match(/entries\.published_at >= .+? AND entries\.published_at <= .+? THEN 1 ELSE 0 END/)
        expect(sql.to_s).to match(/entries\.published_at >= .+? AND entries\.published_at < .+? THEN 1 ELSE 0 END/)
        expect(sql.to_s).to match(/entries\.published_at >= .+? AND entries\.published_at <= .+? THEN entries\.total_count ELSE 0 END/)
        expect(sql.to_s).to match(/entries\.published_at >= .+? AND entries\.published_at < .+? THEN entries\.total_count ELSE 0 END/)
        expect(sql.to_s).to include('THEN entries.total_count ELSE 0 END')
        [3, 2, 45, 30]
      end

      expect(topic.__send__(:temporal_velocity_aggregates)).to eq(
        recent_count: 3,
        previous_count: 2,
        recent_interactions: 45,
        previous_interactions: 30
      )
    end
  end

  describe '#content_half_life' do
    it 'loads only the bounded columns required for its existing heuristic' do
      entries = double('entries')
      allow(topic).to receive(:list_entries).and_return(entries)
      allow(entries).to receive(:where).and_return(entries)
      allow(entries).to receive(:order).with('entries.published_at DESC').and_return(entries)
      allow(entries).to receive(:limit).with(100).and_return(entries)
      expect(entries).to receive(:pluck).with(:published_at, :total_count).and_return(
        [[3.days.ago, 110], [2.days.ago, 55], [1.day.ago, 21]]
      )

      expect(topic.content_half_life).to eq(median_hours: 24.0, average_hours: 26.0, sample_size: 3)
    end
  end

  describe '#temporal_intelligence_summary' do
    it 'retains the existing public summary contract' do
      allow(topic).to receive_messages(
        optimal_publishing_time: { hour: 9 },
        trend_velocity: { direction: 'up' },
        engagement_velocity: { direction: 'stable' },
        content_half_life: { median_hours: 18 },
        peak_publishing_times_by_hour: { 9 => { avg_engagement: 20.0 } },
        peak_publishing_times_by_day: { 'Lunes' => { avg_engagement: 20.0 } }
      )

      expect(topic.temporal_intelligence_summary).to eq(
        optimal_time: { hour: 9 },
        trend_velocity: { direction: 'up' },
        engagement_velocity: { direction: 'stable' },
        content_half_life: { median_hours: 18 },
        peak_hours: [[9, { avg_engagement: 20.0 }]],
        peak_days: [['Lunes', { avg_engagement: 20.0 }]]
      )
    end
  end
end

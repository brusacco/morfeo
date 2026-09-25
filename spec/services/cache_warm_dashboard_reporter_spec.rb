# frozen_string_literal: true

require 'rails_helper'

RSpec.describe CacheWarmDashboardReporter do
  let(:topic) { double('topic', id: 42, name: 'Paraguay') }

  describe '.worker_count' do
    it 'uses four workers when the value is missing or invalid' do
      expect(described_class.worker_count).to eq(4)
      expect(described_class.worker_count('0')).to eq(4)
      expect(described_class.worker_count('-2')).to eq(4)
      expect(described_class.worker_count('invalid')).to eq(4)
    end

    it 'accepts a positive worker count' do
      expect(described_class.worker_count('2')).to eq(2)
    end
  end

  describe '#warm_topic' do
    let(:clock_values) { [0.0, 1.0, 2.0, 3.0, 4.0, 5.0, 6.0, 7.0, 8.0, 9.0, 10.0, 11.0] }
    let(:reporter) { described_class.new(clock: -> { clock_values.shift }) }

    before do
      stub_const('DAYS_RANGE', 7)
      allow(DigitalDashboardServices::AggregatorService).to receive(:call)
      allow(FacebookDashboardServices::AggregatorService).to receive(:call)
      allow(TwitterDashboardServices::AggregatorService).to receive(:call)
      allow(InstagramDashboardServices::AggregatorService).to receive(:call)
      allow(GeneralDashboardServices::AggregatorService).to receive(:call)
    end

    it 'returns timings for every dashboard' do
      result = reporter.warm_topic(topic)

      expect(result).to include(success: true, topic_id: 42, topic_name: 'Paraguay', duration: 11.0)
      expect(result[:dashboards].keys).to eq(%i[digital facebook twitter instagram general])
      expect(result[:dashboards].values).to all(include(:duration, :cache_status))
    end

    it 'preserves previous timings and records dashboard failures' do
      allow(FacebookDashboardServices::AggregatorService).to receive(:call).and_raise(ArgumentError, 'bad payload')

      result = reporter.warm_topic(topic)

      expect(result).to include(success: false, error_class: 'ArgumentError', error: 'bad payload')
      expect(result[:dashboards][:digital]).to include(duration: 1.0)
      expect(result[:dashboards][:facebook]).to include(error_class: 'ArgumentError', error: 'bad payload')
      expect(result[:dashboards][:general]).to include(:duration)
    end
  end

  describe 'aggregate reporting' do
    let(:results) do
      [
        {
          topic_id: 1,
          topic_name: 'Paraguay',
          duration: 10.0,
          dashboards: {
            digital: { duration: 1.0, cache_status: :hit },
            facebook: { duration: 4.0, cache_status: :miss },
            general: { duration: 5.0, cache_status: :miss }
          }
        },
        {
          topic_id: 2,
          topic_name: 'Economia',
          duration: 7.0,
          dashboards: {
            digital: { duration: 3.0, cache_status: :hit },
            facebook: { duration: 2.0, cache_status: :hit },
            general: { duration: 2.0, cache_status: nil }
          }
        }
      ]
    end

    it 'sorts the slowest dashboard calls across topics' do
      slowest = described_class.slowest_dashboard_calls(results, limit: 2)

      expect(
        slowest.map do |call|
          [call[:name], call[:topic_name]]
        end
      ).to eq([[:general, 'Paraguay'], [:facebook, 'Paraguay']])
    end

    it 'calculates aggregate duration and cache statistics' do
      statistics = described_class.aggregate_statistics(results)
      cache_statistics = described_class.cache_statistics(results)

      expect(statistics[:digital]).to include(calls: 2, total: 4.0, average: 2.0, max: 3.0, hits: 2, misses: 0)
      expect(statistics[:general]).to include(calls: 2, hits: 0, misses: 1, unknown: 1)
      expect(cache_statistics).to include(hits: 3, misses: 2, unknown: 1, hit_rate: 60.0)
    end

    it 'is division-by-zero safe for empty results' do
      expect(described_class.cache_statistics([])).to eq(hits: 0, misses: 0, unknown: 0, hit_rate: 0.0)
      expect(described_class.aggregate_statistics([])[:digital]).to include(calls: 0, total: 0, average: 0.0, max: 0.0)
    end
  end
end

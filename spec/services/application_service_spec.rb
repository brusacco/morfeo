# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ApplicationService do
  describe '#fetch_cached_with_race_protection' do
    it 'uses a race-condition TTL while preserving the cache expiration' do
      service = described_class.new

      expect(Rails.cache).to receive(:fetch)
        .with('dashboard:payload', expires_in: 30.minutes, race_condition_ttl: 2.minutes)
        .and_yield

      result =
        service.send(:fetch_cached_with_race_protection, 'dashboard:payload', expires_in: 30.minutes) do
          { cached: 'payload' }
        end

      expect(result).to eq(cached: 'payload')
    end
  end
end

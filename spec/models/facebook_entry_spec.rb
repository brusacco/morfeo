# frozen_string_literal: true

require 'rails_helper'

RSpec.describe FacebookEntry do
  def build_facebook_entry(followers:, interactions: 0, attachment_type: 'photo')
    described_class.new(
      page: build(:page, followers:),
      facebook_post_id: SecureRandom.uuid,
      posted_at: Time.current,
      attachment_type:,
      reactions_total_count: interactions,
      comments_count: 0,
      share_count: 0
    )
  end

  describe '#estimated_reach' do
    it 'returns zero reach and views without followers' do
      entry = build_facebook_entry(followers: 0)

      expect(entry.estimated_reach).to eq(0)
      expect(entry.estimated_views).to eq(0)
    end

    {
      0 => 10_000,
      10_000 => 11_000,
      20_000 => 12_000,
      30_000 => 13_000,
      100_000 => 13_000
    }.each do |interactions, expected_reach|
      it "estimates #{expected_reach} reach for #{interactions} interactions on one million followers" do
        entry = build_facebook_entry(followers: 1_000_000, interactions:)

        expect(entry.estimated_reach).to eq(expected_reach)
      end
    end

    it 'bounds the representative viral case below the previous reach explosion' do
      entry = build_facebook_entry(followers: 2_381_030, interactions: 22_374)

      expect(entry.estimated_reach).to eq(26_048)
      expect(entry.estimated_reach).to be < 100_000
    end

    it 'does not adjust reach by content type' do
      reaches =
        %w[photo video_autoplay share album].map do |attachment_type|
          build_facebook_entry(followers: 1_000_000, interactions: 20_000, attachment_type:).estimated_reach
        end

      expect(reaches.uniq).to eq([12_000])
    end
  end

  describe 'views persistence' do
    it 'uses the existing callback to persist 20% repeated exposure over reach' do
      site = create(:site)
      page_uid = SecureRandom.uuid
      Page.insert!(
        {
          site_id: site.id,
          uid: page_uid,
          name: 'Test Page',
          followers: 1_000_000,
          created_at: Time.current,
          updated_at: Time.current
        }
      )
      entry = described_class.new(
        page: Page.find_by!(uid: page_uid),
        facebook_post_id: SecureRandom.uuid,
        posted_at: Time.current,
        reactions_total_count: 20_000,
        comments_count: 0,
        share_count: 0
      )

      entry.save!

      expect(entry.estimated_views).to eq(14_400.0)
      expect(entry.views_count).to eq(14_400)
    end
  end
end

# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Social tag filtering' do
  let!(:alpha) { create(:tag, name: 'alpha') }
  let!(:beta) { create(:tag, name: 'beta') }

  shared_examples 'an EXISTS tag filter' do |record_factory|
    it 'filters content tags without multiplying a post that has multiple matching tags' do
      record = instance_exec(&record_factory)
      record.tag_list = %w[alpha beta]
      record.save!

      relation = record.class.with_any_tag_ids([alpha.id, beta.id], context: :tags)

      expect(relation.where(id: record.id).count).to eq(1)
      expect(relation.to_sql).to include('EXISTS (SELECT 1 FROM taggings')
    end

    it 'returns an empty relation when no tag IDs are supplied' do
      record = instance_exec(&record_factory)

      expect(record.class.with_any_tag_ids([])).to be_empty
    end

    it 'excludes tags from a different context' do
      record = instance_exec(&record_factory)
      record.tag_list = ['alpha']
      record.save!

      expect(record.class.with_any_tag_ids([alpha.id], context: :other_context)).not_to include(record)
    end
  end

  describe FacebookEntry do
    before do
      allow_any_instance_of(Page).to receive(:update_site_image)
    end

    include_examples 'an EXISTS tag filter',
                     lambda {
                       FacebookEntry.create!(
                         page: create(:page),
                         facebook_post_id: SecureRandom.uuid,
                         posted_at: Time.current
                       )
                     }
  end

  describe TwitterPost do
    include_examples 'an EXISTS tag filter',
                     lambda {
                       profile = TwitterProfile.create!(uid: SecureRandom.uuid, name: 'Profile')
                       TwitterPost.create!(
                         twitter_profile: profile,
                         tweet_id: SecureRandom.uuid,
                         posted_at: Time.current
                       )
                     }
  end

  describe InstagramPost do
    include_examples 'an EXISTS tag filter',
                     lambda {
                       profile = InstagramProfile.create!(uid: SecureRandom.uuid, username: SecureRandom.hex(8))
                       InstagramPost.create!(
                         instagram_profile: profile,
                         shortcode: SecureRandom.hex(8),
                         posted_at: Time.current
                       )
                     }
  end
end

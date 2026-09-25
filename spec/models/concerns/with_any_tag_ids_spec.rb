# frozen_string_literal: true

require 'rails_helper'

RSpec.describe WithAnyTagIds do
  describe '.with_any_tag_ids' do
    it 'filters with a tag relation subquery without loading tag IDs' do
      matching_entry = create(:entry)
      other_entry = create(:entry)
      matching_entry.tag_list = ['matching-tag']
      matching_entry.save!
      other_entry.tag_list = ['other-tag']
      other_entry.save!
      tag_scope = ActsAsTaggableOn::Tag.where(name: 'matching-tag')

      expect(tag_scope).not_to receive(:to_a)

      expect(Entry.with_any_tag_ids(tag_scope, context: :tags)).to contain_exactly(matching_entry)
    end
  end
end

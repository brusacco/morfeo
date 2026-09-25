# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Topic, type: :model do
  it 'is valid with the factory' do
    expect(build(:topic)).to be_valid
  end

  it 'exposes the active scope' do
    active_topic = create(:topic, status: true)
    inactive_topic = create(:topic, status: false)

    expect(described_class.active).to include(active_topic)
    expect(described_class.active).not_to include(inactive_topic)
  end

  it 'matches content tags without including title-tag matches' do
    topic = create(:topic)
    content_entry = create(:entry)
    content_entry.tag_list = ['alpha']
    content_entry.save!

    title_entry = create(:entry)
    title_entry.title_tag_list = ['alpha']
    title_entry.save!

    topic.tags << Tag.find_by!(name: 'alpha')

    expect(topic.entries_matching_tags.pluck(:id)).to contain_exactly(content_entry.id)
  end
end

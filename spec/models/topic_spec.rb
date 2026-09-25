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

  it 'versions its entry cache state from matching entries' do
    topic = create(:topic)
    entry = create(:entry)
    entry.tag_list = ['alpha']
    entry.save!
    entry.update_column(:updated_at, Time.zone.parse('2026-09-25 10:05:00'))
    topic.tags << Tag.find_by!(name: 'alpha')

    expect(topic.entries_cache_version).to match(/\A1:\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}\.\d{6}Z\z/)
  end

  it 'reuses the Facebook entry relation for emotional intensity aggregates' do
    entries = double('entries')
    high_intensity_entries = double('high_intensity_entries', count: 3)
    low_intensity_entries = double('low_intensity_entries', count: 2)
    allow(entries).to receive(:average).with(:emotional_intensity).and_return(42.345)
    allow(entries).to receive(:where)
      .with('emotional_intensity > ?', FacebookEntry::HIGH_EMOTION_THRESHOLD)
      .and_return(high_intensity_entries)
    allow(entries).to receive(:where).with('emotional_intensity < ?', 20.0).and_return(low_intensity_entries)
    expect(entries).not_to receive(:pluck)

    expect(create(:topic).send(:emotional_intensity_analysis, entries)).to eq(
      average_intensity: 42.35,
      high_intensity_count: 3,
      low_intensity_count: 2
    )
  end
end

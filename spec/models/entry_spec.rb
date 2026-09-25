# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Entry, type: :model do
  it 'is valid with the factory' do
    expect(build(:entry)).to be_valid
  end

  it 'returns the ids of positive entries' do
    positive_entry = create(:entry, polarity: :positive)
    create(:entry, polarity: :negative)

    expect(described_class.positives).to eq([positive_entry.id])
  end

  it 'belongs to a site' do
    expect(described_class.reflect_on_association(:site).macro).to eq(:belongs_to)
  end

  it 'matches tagged_with any-tag results across tag contexts' do
    matching_entry = create(:entry)
    matching_entry.tag_list = %w[alpha beta]
    matching_entry.save!

    title_only_entry = create(:entry)
    title_only_entry.title_tag_list = ['alpha']
    title_only_entry.save!

    create(:entry).tap do |entry|
      entry.tag_list = ['gamma']
      entry.save!
    end

    tag_ids = Tag.where(name: %w[alpha beta]).pluck(:id)
    legacy_ids = described_class.tagged_with(%w[alpha beta], any: true).order(:id).pluck(:id)
    optimized_ids = described_class.with_any_tag_ids(tag_ids).order(:id).pluck(:id)

    expect(optimized_ids).to eq(legacy_ids)
    expect(optimized_ids).to include(matching_entry.id)
    expect(optimized_ids).to include(title_only_entry.id)
  end

  it 'filters the requested tag context when one is provided' do
    content_entry = create(:entry)
    content_entry.tag_list = ['alpha']
    content_entry.save!

    title_entry = create(:entry)
    title_entry.title_tag_list = ['alpha']
    title_entry.save!

    alpha_tag_id = Tag.find_by!(name: 'alpha').id

    expect(
      described_class.with_any_tag_ids(
        [alpha_tag_id],
        context: :tags
      ).pluck(:id)
    ).to contain_exactly(content_entry.id)
    expect(
      described_class.with_any_tag_ids(
        [alpha_tag_id],
        context: :title_tags
      ).pluck(:id)
    ).to contain_exactly(title_entry.id)
  end

  it 'returns no entries when no tag ids are provided' do
    expect(described_class.with_any_tag_ids([])).to be_empty
  end

  it 'builds word and bigram occurrences from one relation read' do
    entry = create(:entry, title: 'Alpha beta', content: 'Alpha beta')
    entries = described_class.where(id: entry.id)

    expect(entries).to receive(:pluck).with(:title, :content).once.and_call_original

    expect(entries.text_occurrences).to eq(
      word_occurrences: [['alpha', 2], ['beta', 2]],
      bigram_occurrences: [['alpha beta', 2]]
    )
  end
end

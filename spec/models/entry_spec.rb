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

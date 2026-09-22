# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Newspaper, type: :model do
  it 'is valid with the factory' do
    expect(build(:newspaper)).to be_valid
  end

  it 'belongs to a site and has many newspaper texts' do
    expect(described_class.reflect_on_association(:site).macro).to eq(:belongs_to)
    expect(described_class.reflect_on_association(:newspaper_texts).macro).to eq(:has_many)
  end
end

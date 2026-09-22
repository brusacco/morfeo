# frozen_string_literal: true

require 'rails_helper'

RSpec.describe NewspaperText, type: :model do
  it 'is valid with the factory' do
    expect(build(:newspaper_text)).to be_valid
  end

  it 'belongs to a newspaper' do
    expect(described_class.reflect_on_association(:newspaper).macro).to eq(:belongs_to)
  end
end

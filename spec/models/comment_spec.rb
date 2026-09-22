# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Comment, type: :model do
  it 'is valid with the factory' do
    expect(build(:comment)).to be_valid
  end

  it 'belongs to an entry and touches it' do
    reflection = described_class.reflect_on_association(:entry)

    expect(reflection.macro).to eq(:belongs_to)
    expect(reflection.options[:touch]).to be(true)
  end
end
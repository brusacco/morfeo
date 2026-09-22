# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Report, type: :model do
  it 'is valid with the factory' do
    expect(build(:report)).to be_valid
  end

  it 'belongs to a topic and touches it' do
    reflection = described_class.reflect_on_association(:topic)

    expect(reflection.macro).to eq(:belongs_to)
    expect(reflection.options[:touch]).to be(true)
  end
end
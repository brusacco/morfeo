# frozen_string_literal: true

require 'rails_helper'

RSpec.describe User, type: :model do
  it 'is valid with the factory' do
    expect(build(:user)).to be_valid
  end

  it 'has the expected associations' do
    expect(described_class.reflect_on_association(:user_topics).macro).to eq(:has_many)
    expect(described_class.reflect_on_association(:topics).options[:through]).to eq(:user_topics)
  end
end

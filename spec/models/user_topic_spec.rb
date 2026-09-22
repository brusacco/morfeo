# frozen_string_literal: true

require 'rails_helper'

RSpec.describe UserTopic, type: :model do
  it 'is valid with the factory' do
    expect(build(:user_topic)).to be_valid
  end

  it 'belongs to a user and a topic' do
    expect(described_class.reflect_on_association(:user).macro).to eq(:belongs_to)
    expect(described_class.reflect_on_association(:topic).macro).to eq(:belongs_to)
  end
end
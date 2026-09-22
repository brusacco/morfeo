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
end
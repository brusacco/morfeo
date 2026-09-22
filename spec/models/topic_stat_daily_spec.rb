# frozen_string_literal: true

require 'rails_helper'

RSpec.describe TopicStatDaily, type: :model do
  it 'is valid with the factory' do
    expect(build(:topic_stat_daily)).to be_valid
  end

  it 'exposes the normal_range scope' do
    current_stat = create(:topic_stat_daily, topic_date: Date.current)
    old_stat = create(:topic_stat_daily, topic_date: 1.year.ago)

    expect(described_class.normal_range).to include(current_stat)
    expect(described_class.normal_range).not_to include(old_stat)
  end
end

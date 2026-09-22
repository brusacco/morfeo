# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Template, type: :model do
  it 'is valid with the factory' do
    expect(build(:template)).to be_valid
  end

  it 'swaps the date range when the dates are inverted' do
    template = create(:template, start_date: Date.current, end_date: Date.current - 7)

    expect(template.reload.start_date).to eq(Date.current - 7)
    expect(template.reload.end_date).to eq(Date.current)
  end

  it 'belongs to topic and admin_user' do
    expect(described_class.reflect_on_association(:topic).macro).to eq(:belongs_to)
    expect(described_class.reflect_on_association(:admin_user).macro).to eq(:belongs_to)
  end
end

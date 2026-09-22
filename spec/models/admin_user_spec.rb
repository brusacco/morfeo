# frozen_string_literal: true

require 'rails_helper'

RSpec.describe AdminUser, type: :model do
  it 'is valid with the factory' do
    expect(build(:admin_user)).to be_valid
  end

  it 'has many templates' do
    expect(described_class.reflect_on_association(:templates).macro).to eq(:has_many)
  end
end

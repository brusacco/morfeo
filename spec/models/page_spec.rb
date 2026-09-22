# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Page, type: :model do
  it 'is valid with the factory' do
    expect(build(:page)).to be_valid
  end

  it 'validates uid presence' do
    page = build(:page, uid: nil)

    expect(page).not_to be_valid
    expect(page.errors[:uid]).to include('no puede estar en blanco')
  end

  it 'belongs to a site and has many facebook entries' do
    expect(described_class.reflect_on_association(:site).macro).to eq(:belongs_to)
    expect(described_class.reflect_on_association(:facebook_entries).macro).to eq(:has_many)
  end
end

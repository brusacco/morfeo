# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Site, type: :model do
  it 'validates unique name and url' do
    create(:site, name: 'Example News', url: 'https://example-news.test')

    duplicate_name = build(:site, name: 'Example News', url: 'https://example-news-2.test')
    duplicate_url = build(:site, name: 'Different Name', url: 'https://example-news.test')

    expect(duplicate_name).not_to be_valid
    expect(duplicate_name.errors[:name]).to include('ya está en uso')

    expect(duplicate_url).not_to be_valid
    expect(duplicate_url.errors[:url]).to include('ya está en uso')
  end

  it 'exposes the enabled and disabled scopes' do
    enabled_site = create(:site, status: true)
    disabled_site = create(:site, status: false)

    expect(described_class.enabled).to include(enabled_site)
    expect(described_class.disabled).to include(disabled_site)
  end

  it 'has the expected association definitions' do
    expect(described_class.reflect_on_association(:newspaper).macro).to eq(:has_many)
    expect(described_class.reflect_on_association(:entries).macro).to eq(:has_many)
  end
end

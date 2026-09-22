# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Api::V1::Sites', type: :request do
  let(:site) { create(:site, name: 'News Source', url: 'https://news-source.test') }
  let!(:entry) do
    create(
      :entry,
      site: site,
      title: 'Site entry',
      published_at: Time.current,
      total_count: 18,
      tag_list: [site.name]
    )
  end

  around do |example|
    original = ENV['USE_DIRECT_ENTRY_TOPICS']
    ENV['USE_DIRECT_ENTRY_TOPICS'] = 'true'
    example.run
  ensure
    ENV['USE_DIRECT_ENTRY_TOPICS'] = original
  end

  it 'returns the popular site entries collection' do
    get '/api/v1/sites/popular', params: { query: site.name }, as: :json

    json = JSON.parse(response.body)

    expect(response).to have_http_status(:ok)
    expect(json).to be_an(Array)
    expect(json.first['news']['id']).to eq(entry.id)
  end

  it 'returns the latest site entries collection' do
    get '/api/v1/sites/latest', params: { query: site.name }, as: :json

    json = JSON.parse(response.body)

    expect(response).to have_http_status(:ok)
    expect(json).to be_an(Array)
    expect(json.first['news']['id']).to eq(entry.id)
  end

  it 'searches site entries by query' do
    get '/api/v1/sites/search', params: { query: site.name }, as: :json

    json = JSON.parse(response.body)

    expect(response).to have_http_status(:ok)
    expect(json).to be_an(Array)
    expect(json.first['news']['id']).to eq(entry.id)
  end
end
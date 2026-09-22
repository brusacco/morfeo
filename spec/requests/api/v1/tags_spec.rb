# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Api::V1::Tags', type: :request do
  let(:site) { create(:site, name: 'News Source', url: 'https://news-source.test') }
  let!(:entry) do
    create(
      :entry,
      site: site,
      title: 'Tagged entry',
      published_at: Time.current,
      total_count: 12,
      tag_list: ['economy', 'politics']
    )
  end

  around do |example|
    original = ENV['USE_DIRECT_ENTRY_TOPICS']
    ENV['USE_DIRECT_ENTRY_TOPICS'] = 'true'
    example.run
  ensure
    ENV['USE_DIRECT_ENTRY_TOPICS'] = original
  end

  it 'returns the popular tags collection' do
    get '/api/v1/tags/popular', as: :json

    json = JSON.parse(response.body)

    expect(response).to have_http_status(:ok)
    expect(json).to be_an(Array)
    expect(json.first['tags']['name']).to eq('economy')
  end

  it 'returns the latest tags collection' do
    get '/api/v1/tags/latest', as: :json

    json = JSON.parse(response.body)

    expect(response).to have_http_status(:ok)
    expect(json).to be_an(Array)
    expect(json.map { |tag| tag['tags']['name'] }).to include('economy', 'politics')
  end

  it 'searches tags by name' do
    get '/api/v1/tags/search', params: { q: 'econ' }, as: :json

    json = JSON.parse(response.body)

    expect(response).to have_http_status(:ok)
    expect(json).to be_an(Array)
    expect(json.map { |tag| tag['tags']['name'] }).to include('economy')
  end
end
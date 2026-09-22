# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Api::V1::Entries', type: :request do
  let(:site) { create(:site, name: 'News Source', url: 'https://news-source.test') }
  let(:tag_name) { 'economy' }
  let!(:older_entry) do
    create(
      :entry,
      site: site,
      title: 'Older entry',
      description: 'Older description',
      content: 'Older content',
      published_at: 2.days.ago,
      total_count: 15,
      tag_list: [tag_name]
    )
  end
  let!(:newer_entry) do
    create(
      :entry,
      site: site,
      title: 'Newer entry',
      description: 'Newer description',
      content: 'Newer content',
      published_at: Time.current,
      total_count: 25,
      tag_list: [tag_name]
    )
  end

  it 'returns a single entry as json' do
    get '/api/v1/entries/show', params: { id: newer_entry.id }, as: :json

    json = JSON.parse(response.body)

    expect(response).to have_http_status(:ok)
    expect(json['entry']['id']).to eq(newer_entry.id)
    expect(json['entry']['news_source']).to eq(site.name)
  end

  it 'returns the latest entries collection' do
    get '/api/v1/entries/latest', as: :json

    json = JSON.parse(response.body)

    expect(response).to have_http_status(:ok)
    expect(json).to be_an(Array)
    expect(json.first['news']['id']).to eq(newer_entry.id)
  end

  it 'returns the popular entries collection' do
    get '/api/v1/entries/popular', as: :json

    json = JSON.parse(response.body)

    expect(response).to have_http_status(:ok)
    expect(json).to be_an(Array)
    expect(json.first['news']['id']).to eq(newer_entry.id)
  end

  it 'searches entries by tag' do
    get '/api/v1/entries/search', params: { query: tag_name }, as: :json

    json = JSON.parse(response.body)

    expect(response).to have_http_status(:ok)
    expect(json).to be_an(Array)
    expect(json.map { |item| item['news']['id'] }).to include(older_entry.id, newer_entry.id)
  end

  it 'returns similar entries for a given url' do
    get '/api/v1/entries/similar', params: { url: newer_entry.url }, as: :json

    json = JSON.parse(response.body)

    expect(response).to have_http_status(:ok)
    expect(json).to be_an(Array)
    expect(json.map { |item| item['news']['id'] }).to include(newer_entry.id)
  end
end

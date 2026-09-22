# frozen_string_literal: true

require 'rails_helper'
require 'securerandom'

RSpec.describe 'Api::V1::Topics', type: :request do
  let(:site) { create(:site, name: 'News Source', url: 'https://news-source.test') }
  let(:topic_tag_name) { "economy-api-topics-#{SecureRandom.hex(4)}" }
  let!(:entry) do
    create(
      :entry,
      site: site,
      title: 'Topic entry',
      published_at: 3.days.ago,
      total_count: 8,
      tag_list: [topic_tag_name]
    )
  end

  let(:topic) do
    create(:topic, name: 'Economy').tap do |topic_record|
      topic_record.tags << Tag.find_or_create_by!(name: topic_tag_name)
    end
  end

  it 'returns the popular topic entries collection' do
    get '/api/v1/topics/popular', params: { query: topic.name }, as: :json

    json = JSON.parse(response.body)

    expect(response).to have_http_status(:ok)
    expect(json).to be_an(Array)
    expect(json.first['news']['id']).to eq(entry.id)
  end

  it 'returns no content for the latest endpoint' do
    get '/api/v1/topics/latest', as: :json

    expect(response).to have_http_status(:no_content)
    expect(response.body).to be_empty
  end

  it 'returns no content for the search endpoint' do
    get '/api/v1/topics/search', params: { q: 'econ' }, as: :json

    expect(response).to have_http_status(:no_content)
    expect(response.body).to be_empty
  end
end
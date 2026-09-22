# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'InstagramTopic', type: :request do
  let(:topic) { create(:topic) }

  it 'redirects show when the user cannot access the topic' do
    sign_in create(:user)

    get "/instagram_topics/#{topic.id}"

    expect(response).to redirect_to(root_path)
  end

  it 'redirects pdf when the user cannot access the topic' do
    sign_in create(:user)

    get "/instagram_topics/#{topic.id}/pdf"

    expect(response).to redirect_to(root_path)
  end

  it 'returns entries data for an authenticated user' do
    sign_in create(:user)
    allow(InstagramPost).to receive(:for_topic).and_return(InstagramPost.none)

    get '/instagram_topics/entries_data', params: { topic_id: topic.id }

    expect(response).to have_http_status(:ok)
  end
end
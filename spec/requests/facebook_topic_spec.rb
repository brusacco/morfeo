# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'FacebookTopic', type: :request do
  let(:topic) { create(:topic) }

  it 'redirects show when the user cannot access the topic' do
    sign_in create(:user)

    get "/facebook_topics/#{topic.id}"

    expect(response).to redirect_to(root_path)
  end

  it 'redirects pdf when the user cannot access the topic' do
    sign_in create(:user)

    get "/facebook_topics/#{topic.id}/pdf"

    expect(response).to redirect_to(root_path)
  end

  it 'returns entries data for an authenticated user' do
    sign_in create(:user)
    allow(FacebookEntry).to receive(:for_topic).and_return(FacebookEntry.none)

    get '/facebook_topics/entries_data', params: { topic_id: topic.id }

    expect(response).to have_http_status(:ok)
  end
end
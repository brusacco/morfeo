# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Topic', type: :request do
  it 'gets show' do
    user = create(:user)
    topic = create(:topic)
    create(:user_topic, user: user, topic: topic)
    sign_in user

    get "/topic/#{topic.id}"

    expect(response).to have_http_status(:ok)
  end
end

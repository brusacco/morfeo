# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Home', type: :request do
  it 'gets index' do
    user = create(:user)
    topic = create(:topic)
    create(:user_topic, user: user, topic: topic)
    sign_in user

    get '/home/index'

    expect(response).to have_http_status(:ok)
  end
end

# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Entry', type: :request do
  it 'gets show' do
    sign_in create(:user)

    get '/entry/show'

    expect(response).to have_http_status(:ok)
  end
end

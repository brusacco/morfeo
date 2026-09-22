# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Site', type: :request do
  it 'gets show' do
    sign_in create(:user)
    site = create(:site)

    get "/site/#{site.id}"

    expect(response).to have_http_status(:ok)
  end
end

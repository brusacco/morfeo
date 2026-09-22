# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'GeneralDashboard', type: :request do
  let(:topic) { create(:topic) }

  it 'redirects show when the user cannot access the topic' do
    sign_in create(:user)

    get "/general_dashboards/#{topic.id}"

    expect(response).to redirect_to(root_path)
  end

  it 'redirects pdf when the user cannot access the topic' do
    sign_in create(:user)

    get "/general_dashboards/#{topic.id}/pdf"

    expect(response).to redirect_to(root_path)
  end
end
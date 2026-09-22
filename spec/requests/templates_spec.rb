# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Templates', type: :request do
  it 'gets show' do
    template = create(:template)

    get "/templates/#{template.id}"

    expect(response).to redirect_to(new_admin_user_session_path)
  end
end

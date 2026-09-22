# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Tag', type: :request do
  it 'gets show' do
    sign_in create(:user)

    get '/tag/show'

    expect(response).to redirect_to(root_path)
  end
end

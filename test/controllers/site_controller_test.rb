# frozen_string_literal: true

require 'test_helper'

class SiteControllerTest < ActionDispatch::IntegrationTest
  test 'should get show' do
    get site_show_url
    assert_response :success
  end
end

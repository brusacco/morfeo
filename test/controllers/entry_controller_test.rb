# frozen_string_literal: true

require 'test_helper'

class EntryControllerTest < ActionDispatch::IntegrationTest
  test 'should get show' do
    get entry_show_url
    assert_response :success
  end
end

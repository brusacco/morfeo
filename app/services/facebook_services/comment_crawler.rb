# frozen_string_literal: true

module FacebookServices
  class CommentCrawler < ApplicationService
    def initialize(post_uid)
      @post_uid = post_uid
    end

    def call
      response = api_call(@post_uid)
      if response['error']
        handle_error(response['error']['message'])
      else
        result = { comments: response['data'] }
        handle_success(result)
      end
    end

    def api_call(post_uid)
      api_url = 'https://graph.facebook.com/v8.0/'
      token = '&access_token=1442100149368278|KS0hVFPE6HgqQ2eMYG_kBpfwjyo'
      request = "#{api_url}#{post_uid}/comments?limit=500#{token}"
      response = HTTParty.get(request)
      JSON.parse(response.body)
    end
  end
end

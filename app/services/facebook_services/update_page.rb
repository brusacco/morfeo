# frozen_string_literal: true

module FacebookServices
  class UpdatePage < ApplicationService
    def initialize(uid)
      @uid = uid
    end

    def call
      api_url = 'https://graph.facebook.com/v8.0/'
      token = '1442100149368278|KS0hVFPE6HgqQ2eMYG_kBpfwjyo'
      request = "#{api_url}/#{@uid}?fields=cover%2Cusername%2Cpicture%2Cname%2Cfan_count%2Ccategory%2Cdescription%2Cid%2Cwebsite&access_token=#{token}"
      response = HTTParty.get(request)
      parsed = JSON.parse(response.body)

      result = {
        username: parsed['username'],
        name: parsed['name'],
        followers: parsed['fan_count'],
        category: parsed['category'],
        description: parsed['description'],
        website: parsed['website'],
        picture: parsed['picture']['data']['url']
      }
      handle_success(result)
    end
  end
end

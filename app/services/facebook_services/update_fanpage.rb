# frozen_string_literal: true

require 'json'
require 'open-uri'
require 'uri'

module FacebookServices
  class UpdateFanpage < ApplicationService
    def initialize(page_uid)
      @page_uid = page_uid
    end

    def call
      api_url = 'https://graph.facebook.com/v8.0/'
      token = '&access_token=1442100149368278|KS0hVFPE6HgqQ2eMYG_kBpfwjyo'
      reactions = '%2Creactions.type(LIKE).limit(0).summary(total_count).as(reactions_like)%2Creactions.type(LOVE).limit(0).summary(total_count).as(reactions_love)%2Creactions.type(WOW).limit(0).summary(total_count).as(reactions_wow)%2Creactions.type(HAHA).limit(0).summary(total_count).as(reactions_haha)%2Creactions.type(SAD).limit(0).summary(total_count).as(reactions_sad)%2Creactions.type(ANGRY).limit(0).summary(total_count).as(reactions_angry)%2Creactions.type(THANKFUL).limit(0).summary(total_count).as(reactions_thankful)'
      comments = '%2Ccomments.limit(0).summary(total_count)'
      shares = '%2Cshares'
      limit = '&limit=100'

      url = "/#{@page_uid}/posts?fields=id%2Cattachments%2Ccreated_time%2Cmessage"
      request = "#{api_url}#{url}#{shares}#{comments}#{reactions}#{limit}#{token}"

      response = HTTParty.get(request)
      data = JSON.parse(response.body)
    end
  end
end

# frozen_string_literal: true

require 'json'
require 'open-uri'
require 'uri'
require 'cgi'

module FacebookServices
  class FanpageCrawler < ApplicationService
    def initialize(page_uid, cursor = nil)
      @page_uid = page_uid
      @cursor = cursor
    end

    def call
      posts = {}
      data = call_api(@page_uid, @cursor)
      data['data'].each do |post|
        next unless post['attachments'] &&
                    post['attachments']['data'] &&
                    post['attachments']['data'][0] &&
                    post['attachments']['data'][0]['type'] == 'share'

        facebook_url = post['attachments']['data'][0]['target']['url']
        target_url = facebook_url.match(/u=([^&]+)/)
        next if target_url.nil?

        target_url = CGI.unescape(target_url[1]) # Decode URL encoding
        posts[post['id']] = target_url
      end

      if data['paging'] && data['paging']['cursors'] && data['paging']['cursors']['after']
        cursor = data['paging']['cursors']['after']
      else
        cursor = nil
      end

      result = { posts: posts, next: cursor }
      handle_success(result)
    rescue StandardError => e
      handle_error(e)
    end

    def call_api(page_uid, cursor = nil)
      api_url = 'https://graph.facebook.com/v8.0/'
      token = '&access_token=1442100149368278|KS0hVFPE6HgqQ2eMYG_kBpfwjyo'
      reactions = '%2Creactions.type(LIKE).limit(0).summary(total_count).as(reactions_like)%2Creactions.type(LOVE).limit(0).summary(total_count).as(reactions_love)%2Creactions.type(WOW).limit(0).summary(total_count).as(reactions_wow)%2Creactions.type(HAHA).limit(0).summary(total_count).as(reactions_haha)%2Creactions.type(SAD).limit(0).summary(total_count).as(reactions_sad)%2Creactions.type(ANGRY).limit(0).summary(total_count).as(reactions_angry)%2Creactions.type(THANKFUL).limit(0).summary(total_count).as(reactions_thankful)'
      comments = '%2Ccomments.limit(0).summary(total_count)'
      shares = '%2Cshares'
      limit = '&limit=100'
      next_page = cursor ? "&after=#{cursor}" : ''

      url = "/#{page_uid}/posts?fields=id%2Cattachments%2Ccreated_time%2Cmessage"
      request = "#{api_url}#{url}#{shares}#{comments}#{reactions}#{limit}#{token}#{next_page}"

      response = HTTParty.get(request)
      JSON.parse(response.body)
    end
  end
end

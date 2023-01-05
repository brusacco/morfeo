# frozen_string_literal: true

module FacebookServices
  class UpdateStats < ApplicationService
    def initialize(id)
      @entry_id = id
    end

    def call
      entry = Entry.find(@entry_id)
      token = '1442100149368278|52cd0715eae80b831d25db730046bc93'
      request = "https://graph.facebook.com/v11.0/?id=#{CGI.escape(entry.url)}&fields=engagement&access_token=#{token}"
      response = HTTParty.get(request)
      data = JSON.parse(response.body)
      engagement = data['engagement']
      total = engagement['reaction_count'] + engagement['comment_count'] + engagement['share_count'] + engagement['comment_plugin_count']
      engagement['total_count'] = total
      handle_success(data['engagement'])
    end
  end
end

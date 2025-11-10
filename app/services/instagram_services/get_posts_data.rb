# frozen_string_literal: true

require 'httparty'
require 'json'

module InstagramServices
  # Service to fetch Instagram posts data from Influencers API
  # Uses the posts endpoint to get all posts for a profile
  class GetPostsData < ApplicationService
    include HTTParty

    base_uri 'https://www.influencers.com.py/api/v1'

    def initialize(username)
      @username = username
      @token = ENV['INFLUENCERS_TOKEN']
    end

    def call
      return handle_error('Missing INFLUENCERS_TOKEN') if @token.blank?
      return handle_error('Missing username') if @username.blank?

      response = self.class.get(
        "/profiles/#{@username}/posts",
        query: { token: @token },
        headers: { 'Content-Type' => 'application/json' },
        timeout: 30
      )

      if response.success?
        data = JSON.parse(response.body)
        handle_success(data)
      else
        handle_error("API Error: #{response.code} - #{response.message}")
      end
    rescue JSON::ParserError => e
      handle_error("JSON parsing error: #{e.message}")
    rescue HTTParty::Error => e
      handle_error("HTTP error: #{e.message}")
    rescue StandardError => e
      handle_error("Unexpected error: #{e.message}")
    end
  end
end


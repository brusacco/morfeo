# frozen_string_literal: true

module FacebookServices
  class CommentCrawler < ApplicationService
    # Timeouts
    TIMEOUT_SECONDS = 30
    OPEN_TIMEOUT_SECONDS = 10

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
      token = ENV.fetch('FACEBOOK_API_TOKEN') do
        raise ArgumentError, 'FACEBOOK_API_TOKEN environment variable is not set. Please add it to your .env file.'
      end
      token_param = "&access_token=#{token}"
      request = "#{api_url}#{post_uid}/comments?limit=100#{token_param}"

      response = HTTParty.get(
        request,
        timeout: TIMEOUT_SECONDS,
        open_timeout: OPEN_TIMEOUT_SECONDS,
        headers: {
          'User-Agent' => 'Morfeo/1.0',
          'Accept' => 'application/json'
        }
      )

      # Parse response
      data = JSON.parse(response.body)

      # Check for API errors
      if data['error']
        error_message = data['error']['message']
        error_code = data['error']['code']
        Rails.logger.error("[FacebookServices::CommentCrawler] API error (code: #{error_code}): #{error_message}")
      end

      # Check HTTP status
      unless response.success?
        Rails.logger.error("[FacebookServices::CommentCrawler] HTTP #{response.code}: #{response.body[0..200]}")
      end

      data
    rescue Net::OpenTimeout, Net::ReadTimeout => e
      Rails.logger.error("[FacebookServices::CommentCrawler] Timeout for post #{post_uid}: #{e.message}")
      { 'error' => { 'message' => "Facebook API timeout: #{e.message}" } }
    rescue JSON::ParserError => e
      Rails.logger.error("[FacebookServices::CommentCrawler] Invalid JSON response: #{response&.body&.[](0..200)}")
      { 'error' => { 'message' => 'Invalid JSON from Facebook API' } }
    rescue SocketError, Errno::ECONNREFUSED, Errno::EHOSTUNREACH => e
      Rails.logger.error("[FacebookServices::CommentCrawler] Network error: #{e.class} - #{e.message}")
      { 'error' => { 'message' => "Network error: #{e.message}" } }
    rescue StandardError => e
      Rails.logger.error("[FacebookServices::CommentCrawler] Unexpected error: #{e.class} - #{e.message}")
      { 'error' => { 'message' => "Unexpected error: #{e.message}" } }
    end
  end
end

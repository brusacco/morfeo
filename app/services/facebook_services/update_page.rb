# frozen_string_literal: true

module FacebookServices
  class UpdatePage < ApplicationService
    # Timeouts
    TIMEOUT_SECONDS = 30
    OPEN_TIMEOUT_SECONDS = 10

    def initialize(uid)
      @uid = uid
    end

    def call
      api_url = 'https://graph.facebook.com/v8.0/'
      token = ENV.fetch('FACEBOOK_API_TOKEN') do
        raise ArgumentError, 'FACEBOOK_API_TOKEN environment variable is not set. Please add it to your .env file.'
      end
      request = "#{api_url}/#{@uid}?fields=cover%2Cusername%2Cpicture%2Cname%2Cfan_count%2Ccategory%2Cdescription%2Cid%2Cwebsite&access_token=#{token}"

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
      parsed = JSON.parse(response.body)

      # Check for API errors
      if parsed['error']
        error_message = parsed['error']['message']
        error_code = parsed['error']['code']
        Rails.logger.error("[FacebookServices::UpdatePage] API error (code: #{error_code}): #{error_message}")
        return handle_error("Facebook API error: #{error_message}")
      end

      # Check HTTP status
      unless response.success?
        Rails.logger.error("[FacebookServices::UpdatePage] HTTP #{response.code}: #{response.body[0..200]}")
        return handle_error("Facebook API returned HTTP #{response.code}")
      end

      result = {
        username: parsed['username'],
        name: parsed['name'],
        followers: parsed['fan_count'],
        category: parsed['category'],
        description: parsed['description'],
        website: parsed&.dig('website') || nil,
        picture: parsed&.dig('picture', 'data', 'url') || nil
      }
      handle_success(result)
    rescue Net::OpenTimeout, Net::ReadTimeout => e
      Rails.logger.error("[FacebookServices::UpdatePage] Timeout for page #{@uid}: #{e.message}")
      handle_error("Facebook API timeout: #{e.message}")
    rescue JSON::ParserError => e
      Rails.logger.error("[FacebookServices::UpdatePage] Invalid JSON response: #{response&.body&.[](0..200)}")
      handle_error('Invalid JSON from Facebook API')
    rescue SocketError, Errno::ECONNREFUSED, Errno::EHOSTUNREACH => e
      Rails.logger.error("[FacebookServices::UpdatePage] Network error: #{e.class} - #{e.message}")
      handle_error("Network error: #{e.message}")
    rescue StandardError => e
      Rails.logger.error("[FacebookServices::UpdatePage] Unexpected error: #{e.class} - #{e.message}")
      handle_error("Unexpected error: #{e.message}")
    end
  end
end

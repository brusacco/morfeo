# frozen_string_literal: true

module FacebookServices
  class UpdateStats < ApplicationService
    # Timeouts
    TIMEOUT_SECONDS = 30
    OPEN_TIMEOUT_SECONDS = 10

    def initialize(id)
      @entry_id = id
    end

    def call
      entry = Entry.find(@entry_id)
      token = ENV.fetch('FACEBOOK_API_TOKEN') do
        raise ArgumentError, 'FACEBOOK_API_TOKEN environment variable is not set. Please add it to your .env file.'
      end
      request = "https://graph.facebook.com/v11.0/?id=#{CGI.escape(entry.url)}&fields=engagement&access_token=#{token}"

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
        Rails.logger.error("[FacebookServices::UpdateStats] API error (code: #{error_code}): #{error_message}")
        return handle_error("Facebook API error: #{error_message}")
      end

      # Check HTTP status
      unless response.success?
        Rails.logger.error("[FacebookServices::UpdateStats] HTTP #{response.code}: #{response.body[0..200]}")
        return handle_error("Facebook API returned HTTP #{response.code}")
      end

      # Check if engagement data exists
      unless data['engagement']
        Rails.logger.warn("[FacebookServices::UpdateStats] No engagement data for entry #{entry.id} (#{entry.url})")
        return handle_error('No engagement data available')
      end

      engagement = data['engagement']
      total = engagement['reaction_count'] + engagement['comment_count'] + engagement['share_count'] + engagement['comment_plugin_count']
      engagement['total_count'] = total
      handle_success(data['engagement'])
    rescue Net::OpenTimeout, Net::ReadTimeout => e
      Rails.logger.error("[FacebookServices::UpdateStats] Timeout for entry #{@entry_id}: #{e.message}")
      handle_error("Facebook API timeout: #{e.message}")
    rescue JSON::ParserError => e
      Rails.logger.error("[FacebookServices::UpdateStats] Invalid JSON response: #{response&.body&.[](0..200)}")
      handle_error('Invalid JSON from Facebook API')
    rescue SocketError, Errno::ECONNREFUSED, Errno::EHOSTUNREACH => e
      Rails.logger.error("[FacebookServices::UpdateStats] Network error: #{e.class} - #{e.message}")
      handle_error("Network error: #{e.message}")
    rescue ActiveRecord::RecordNotFound => e
      Rails.logger.error("[FacebookServices::UpdateStats] Entry not found: #{@entry_id}")
      handle_error("Entry not found: #{@entry_id}")
    rescue StandardError => e
      Rails.logger.error("[FacebookServices::UpdateStats] Unexpected error: #{e.class} - #{e.message}")
      handle_error("Unexpected error: #{e.message}")
    end
  end
end

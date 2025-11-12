# frozen_string_literal: true

module FacebookServices
  class UpdateStats < ApplicationService
    # Timeouts - Increased to handle slow API responses
    TIMEOUT_SECONDS = 45
    OPEN_TIMEOUT_SECONDS = 15

    # Retry configuration
    MAX_RETRIES = 3
    INITIAL_RETRY_DELAY = 2 # seconds

    def initialize(id)
      @entry_id = id
    end

    def call
      entry = Entry.find(@entry_id)
      token = ENV.fetch('FACEBOOK_API_TOKEN') do
        raise ArgumentError, 'FACEBOOK_API_TOKEN environment variable is not set. Please add it to your .env file.'
      end

      request = "https://graph.facebook.com/v11.0/?id=#{CGI.escape(entry.url)}&fields=engagement&access_token=#{token}"

      # Retry logic with exponential backoff
      retries = 0
      last_error = nil

      begin
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

          # Don't retry on authentication errors
          if [190, 102].include?(error_code)
            Rails.logger.error("[FacebookServices::UpdateStats] API auth error (code: #{error_code}) for entry #{@entry_id}: #{error_message}")
            return handle_error("Facebook API authentication error: #{error_message}")
          end

          # Don't retry on rate limits (let the caller handle it)
          if [4, 17, 32, 613].include?(error_code)
            Rails.logger.warn("[FacebookServices::UpdateStats] Rate limit (code: #{error_code}) for entry #{@entry_id}")
            return handle_error("Facebook API rate limit: #{error_message}")
          end

          Rails.logger.error("[FacebookServices::UpdateStats] API error (code: #{error_code}) for entry #{@entry_id}: #{error_message}")
          return handle_error("Facebook API error: #{error_message}")
        end

        # Check HTTP status
        unless response.success?
          Rails.logger.error("[FacebookServices::UpdateStats] HTTP #{response.code} for entry #{@entry_id}: #{response.body[0..200]}")
          return handle_error("Facebook API returned HTTP #{response.code}")
        end

        # Check if engagement data exists
        unless data['engagement']
          Rails.logger.warn("[FacebookServices::UpdateStats] No engagement data for entry #{@entry_id} (#{entry.url})")
          return handle_error('No engagement data available')
        end

        engagement = data['engagement']
        total = engagement['reaction_count'] + engagement['comment_count'] + engagement['share_count'] + engagement['comment_plugin_count']
        engagement['total_count'] = total
        handle_success(data['engagement'])

      rescue Net::OpenTimeout, Net::ReadTimeout => e
        retries += 1
        last_error = e

        if retries < MAX_RETRIES
          delay = INITIAL_RETRY_DELAY * (2 ** (retries - 1)) # Exponential backoff: 2s, 4s, 8s
          Rails.logger.warn("[FacebookServices::UpdateStats] Timeout for entry #{@entry_id} (attempt #{retries}/#{MAX_RETRIES}), retrying in #{delay}s...")
          sleep(delay)
          retry
        else
          Rails.logger.error("[FacebookServices::UpdateStats] Timeout for entry #{@entry_id} after #{MAX_RETRIES} attempts: #{e.message}")
          handle_error("Facebook API timeout after #{MAX_RETRIES} attempts: #{e.message}")
        end

      rescue SocketError, Errno::ECONNREFUSED, Errno::EHOSTUNREACH => e
        retries += 1
        last_error = e

        if retries < MAX_RETRIES
          delay = INITIAL_RETRY_DELAY * (2 ** (retries - 1))
          Rails.logger.warn("[FacebookServices::UpdateStats] Network error for entry #{@entry_id} (attempt #{retries}/#{MAX_RETRIES}), retrying in #{delay}s...")
          sleep(delay)
          retry
        else
          Rails.logger.error("[FacebookServices::UpdateStats] Network error for entry #{@entry_id} after #{MAX_RETRIES} attempts: #{e.class} - #{e.message}")
          handle_error("Network error after #{MAX_RETRIES} attempts: #{e.message}")
        end

      rescue Errno::ECONNRESET, Errno::ETIMEDOUT => e
        retries += 1
        last_error = e

        if retries < MAX_RETRIES
          delay = INITIAL_RETRY_DELAY * (2 ** (retries - 1))
          Rails.logger.warn("[FacebookServices::UpdateStats] Connection reset/timeout for entry #{@entry_id} (attempt #{retries}/#{MAX_RETRIES}), retrying in #{delay}s...")
          sleep(delay)
          retry
        else
          Rails.logger.error("[FacebookServices::UpdateStats] Connection reset/timeout for entry #{@entry_id} after #{MAX_RETRIES} attempts: #{e.class} - #{e.message}")
          handle_error("Connection reset/timeout after #{MAX_RETRIES} attempts: #{e.message}")
        end

      rescue OpenSSL::SSL::SSLError => e
        retries += 1
        last_error = e

        if retries < MAX_RETRIES
          delay = INITIAL_RETRY_DELAY * (2 ** (retries - 1))
          Rails.logger.warn("[FacebookServices::UpdateStats] SSL error for entry #{@entry_id} (attempt #{retries}/#{MAX_RETRIES}), retrying in #{delay}s...")
          sleep(delay)
          retry
        else
          Rails.logger.error("[FacebookServices::UpdateStats] SSL error for entry #{@entry_id} after #{MAX_RETRIES} attempts: #{e.class} - #{e.message}")
          handle_error("SSL error after #{MAX_RETRIES} attempts: #{e.message}")
        end

      rescue JSON::ParserError => e
        Rails.logger.error("[FacebookServices::UpdateStats] Invalid JSON response for entry #{@entry_id}: #{response&.body&.[](0..200)}")
        handle_error('Invalid JSON from Facebook API')

      rescue ActiveRecord::RecordNotFound => e
        Rails.logger.error("[FacebookServices::UpdateStats] Entry not found: #{@entry_id}")
        handle_error("Entry not found: #{@entry_id}")

      rescue StandardError => e
        Rails.logger.error("[FacebookServices::UpdateStats] Unexpected error for entry #{@entry_id}: #{e.class} - #{e.message}")
        Rails.logger.error(e.backtrace.first(5).join("\n")) if e.backtrace
        handle_error("Unexpected error: #{e.message}")
      end
    end
  end
end

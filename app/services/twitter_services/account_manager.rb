# frozen_string_literal: true

module TwitterServices
  # TwitterServices::AccountManager
  #
  # Centralized manager for Twitter API authentication with automatic account rotation
  # to handle rate limits and API restrictions.
  #
  # Features:
  # - Manages multiple Twitter accounts (credentials)
  # - Automatically rotates accounts when rate limits are hit
  # - Tracks cooldown periods for rate-limited accounts
  # - Provides retry logic with exponential backoff
  # - Uses Rails.cache to persist state across requests
  #
  # ENV Variables Required:
  # Primary Account:
  #   - TWITTER_AUTH_TOKEN
  #   - TWITTER_CT0_TOKEN
  #
  # Secondary Account (for rotation):
  #   - TWITTER_AUTH_TOKEN2
  #   - TWITTER_CT0_TOKEN2
  #
  # Tertiary Account (optional - for additional capacity):
  #   - TWITTER_AUTH_TOKEN3
  #   - TWITTER_CT0_TOKEN3
  #
  # Fourth Account (optional - for additional capacity):
  #   - TWITTER_AUTH_TOKEN4
  #   - TWITTER_CT0_TOKEN4
  #
  # Fifth Account (optional - for additional capacity):
  #   - TWITTER_AUTH_TOKEN5
  #   - TWITTER_CT0_TOKEN5
  #
  # Usage:
  #   manager = TwitterServices::AccountManager.new
  #   credentials = manager.get_active_credentials
  #   # ... make API request ...
  #   manager.mark_rate_limited(account_index) if rate_limit_error
  #
  class AccountManager
    # Rate limit cooldown period (15 minutes - Twitter's standard window)
    COOLDOWN_PERIOD = 15.minutes

    # Cache key prefix for tracking account states
    CACHE_PREFIX = 'twitter_account_manager'

    # Error codes and messages that indicate rate limiting
    RATE_LIMIT_INDICATORS = [
      'Rate limit',
      'rate limit',
      'Too Many Requests',
      'code: 88', # Twitter API error code for rate limit
      'code: 326', # Account temporarily locked
      'code: 429' # HTTP Too Many Requests
    ].freeze

    def initialize
      @accounts = load_accounts
      validate_accounts!
    end

    # Get credentials for the currently active (non-rate-limited) account
    # Returns: Hash with :auth_token, :ct0_token, :account_index, :account_name
    def get_active_credentials
      # Try to find a non-rate-limited account
      @accounts.each_with_index do |account, index|
        next if account_rate_limited?(index)

        Rails.logger.info("[TwitterAccountManager] Using #{account[:name]} (not rate limited)")
        return account.merge(account_index: index)
      end

      # If all accounts are rate limited, use the one with earliest cooldown expiry
      account_index = find_least_recently_limited_account
      account = @accounts[account_index]

      remaining_cooldown = get_remaining_cooldown(account_index)
      Rails.logger.warn("[TwitterAccountManager] All accounts rate limited. Using #{account[:name]} (cooldown: #{remaining_cooldown}s remaining)")

      account.merge(account_index: account_index)
    end

    # Mark an account as rate limited (starts cooldown period)
    def mark_rate_limited(account_index, error_message = nil)
      return unless valid_account_index?(account_index)

      account = @accounts[account_index]
      cooldown_until = Time.current + COOLDOWN_PERIOD

      Rails.cache.write(
        rate_limit_cache_key(account_index),
        cooldown_until.to_i,
        expires_in: COOLDOWN_PERIOD + 1.minute # Extra buffer
      )

      Rails.logger.error(
        "[TwitterAccountManager] #{account[:name]} marked as RATE LIMITED until #{cooldown_until.strftime('%H:%M:%S')}. " \
        "Error: #{error_message}"
      )

      # Try to switch to another account
      next_account = get_active_credentials
      if next_account[:account_index] != account_index
        Rails.logger.info("[TwitterAccountManager] Switching to #{next_account[:name]}")
      end
    end

    # Check if a specific account is currently rate limited
    def account_rate_limited?(account_index)
      return false unless valid_account_index?(account_index)

      cooldown_until = Rails.cache.read(rate_limit_cache_key(account_index))
      return false if cooldown_until.nil?

      Time.current.to_i < cooldown_until
    end

    # Get remaining cooldown time in seconds for an account
    def get_remaining_cooldown(account_index)
      cooldown_until = Rails.cache.read(rate_limit_cache_key(account_index))
      return 0 if cooldown_until.nil?

      remaining = cooldown_until - Time.current.to_i
      [remaining, 0].max
    end

    # Check if an error message indicates rate limiting
    def self.rate_limit_error?(error_message)
      return false if error_message.blank?

      RATE_LIMIT_INDICATORS.any? { |indicator| error_message.to_s.include?(indicator) }
    end

    # Get status of all accounts (for monitoring/debugging)
    def accounts_status
      @accounts.map.with_index do |account, index|
        rate_limited = account_rate_limited?(index)
        cooldown = get_remaining_cooldown(index)

        {
          name: account[:name],
          index: index,
          rate_limited: rate_limited,
          cooldown_remaining_seconds: cooldown,
          available: !rate_limited
        }
      end
    end

    # Execute a block with automatic retry and account rotation
    # Usage:
    #   manager.with_retry do |credentials|
    #     make_twitter_api_call(credentials)
    #   end
    def with_retry(max_attempts: 3, &block)
      attempts = 0
      last_error = nil

      while attempts < max_attempts
        attempts += 1
        credentials = get_active_credentials
        current_account_index = credentials[:account_index]

        begin
          result = yield(credentials)

          # If we get here, the request succeeded
          Rails.logger.info("[TwitterAccountManager] Request succeeded with #{credentials[:name]} (attempt #{attempts})")
          return result

        rescue StandardError => e
          last_error = e
          error_message = e.message

          Rails.logger.error(
            "[TwitterAccountManager] Request failed with #{credentials[:name]} " \
            "(attempt #{attempts}/#{max_attempts}): #{error_message}"
          )

          # Check if this is a rate limit error
          if self.class.rate_limit_error?(error_message)
            mark_rate_limited(current_account_index, error_message)

            # If we still have attempts left, try with another account
            if attempts < max_attempts
              wait_time = [2**attempts, 10].min # Exponential backoff, max 10s
              Rails.logger.info("[TwitterAccountManager] Waiting #{wait_time}s before retry...")
              sleep(wait_time)
              next # Try again with rotated account
            end
          else
            # Non-rate-limit error - don't retry, just re-raise
            raise
          end
        end
      end

      # All attempts exhausted
      raise last_error || StandardError.new("All retry attempts exhausted")
    end

    private

    def load_accounts
      accounts = []

      # Primary account
      if ENV['TWITTER_AUTH_TOKEN'].present? && ENV['TWITTER_CT0_TOKEN'].present?
        accounts << {
          name: 'Account 1 (Primary)',
          auth_token: ENV['TWITTER_AUTH_TOKEN'],
          ct0_token: ENV['TWITTER_CT0_TOKEN']
        }
      end

      # Secondary account
      if ENV['TWITTER_AUTH_TOKEN2'].present? && ENV['TWITTER_CT0_TOKEN2'].present?
        accounts << {
          name: 'Account 2 (Secondary)',
          auth_token: ENV['TWITTER_AUTH_TOKEN2'],
          ct0_token: ENV['TWITTER_CT0_TOKEN2']
        }
      end

      # Tertiary account
      if ENV['TWITTER_AUTH_TOKEN3'].present? && ENV['TWITTER_CT0_TOKEN3'].present?
        accounts << {
          name: 'Account 3 (Tertiary)',
          auth_token: ENV['TWITTER_AUTH_TOKEN3'],
          ct0_token: ENV['TWITTER_CT0_TOKEN3']
        }
      end

      # Fourth account
      if ENV['TWITTER_AUTH_TOKEN4'].present? && ENV['TWITTER_CT0_TOKEN4'].present?
        accounts << {
          name: 'Account 4 (Quaternary)',
          auth_token: ENV['TWITTER_AUTH_TOKEN4'],
          ct0_token: ENV['TWITTER_CT0_TOKEN4']
        }
      end

      # Fifth account
      if ENV['TWITTER_AUTH_TOKEN5'].present? && ENV['TWITTER_CT0_TOKEN5'].present?
        accounts << {
          name: 'Account 5 (Quinary)',
          auth_token: ENV['TWITTER_AUTH_TOKEN5'],
          ct0_token: ENV['TWITTER_CT0_TOKEN5']
        }
      end

      accounts
    end

    def validate_accounts!
      if @accounts.empty?
        raise ArgumentError, 'No Twitter accounts configured. Set TWITTER_AUTH_TOKEN and TWITTER_CT0_TOKEN environment variables.'
      end

      Rails.logger.info("[TwitterAccountManager] Initialized with #{@accounts.count} account(s)")
      @accounts.each_with_index do |account, index|
        Rails.logger.info("  [#{index}] #{account[:name]}")
      end
    end

    def valid_account_index?(index)
      index >= 0 && index < @accounts.count
    end

    def find_least_recently_limited_account
      # Find the account whose cooldown will expire first
      min_cooldown = Float::INFINITY
      selected_index = 0

      @accounts.each_index do |index|
        cooldown = get_remaining_cooldown(index)
        if cooldown < min_cooldown
          min_cooldown = cooldown
          selected_index = index
        end
      end

      selected_index
    end

    def rate_limit_cache_key(account_index)
      "#{CACHE_PREFIX}:rate_limited:account_#{account_index}"
    end
  end
end


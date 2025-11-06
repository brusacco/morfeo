# frozen_string_literal: true

require 'json'
require 'open-uri'
require 'uri'
require 'cgi'

module FacebookServices
  class FanpageCrawler < ApplicationService
    # Reaction types supported by Facebook
    REACTION_TYPES = %w[like love wow haha sad angry thankful].freeze

    # API Configuration
    API_VERSION = 'v8.0'
    API_BASE_URL = 'https://graph.facebook.com'

    # Timeout settings (in seconds)
    TIMEOUT_SECONDS = 30        # Read timeout: how long to wait for response
    OPEN_TIMEOUT_SECONDS = 10   # Connection timeout: how long to wait for connection

    # Pagination
    API_PAGE_SIZE = 100         # Number of posts per API request

    # Rate limiting
    DEFAULT_WAIT_TIME = 60      # Default wait time when rate limited (seconds)
    RATE_LIMIT_ERROR_CODES = [4, 17, 32, 613].freeze

    # Authentication errors
    AUTH_ERROR_CODES = [190, 102].freeze

    # Retry configuration
    MAX_RETRIES = 3             # Maximum number of retry attempts
    INITIAL_RETRY_DELAY = 2     # Initial delay in seconds (will increase exponentially)
    MAX_RETRY_DELAY = 60        # Maximum delay between retries

    def initialize(page_uid, cursor = nil)
      @page_uid = page_uid
      @cursor = cursor
    end

    def call
      page = Page.find_by!(uid: @page_uid)
      data = call_api_with_retry(page.uid, @cursor)

      entries =
        Array(data['data']).filter_map do |post|
          persist_entry(page, post)
        end

      result = { entries: entries, next: data.dig('paging', 'cursors', 'after') }

      handle_success(result)
    rescue StandardError => e
      handle_error(e)
    end

    private

    def persist_entry(page, post)
      facebook_entry = FacebookEntry.find_or_initialize_by(facebook_post_id: post['id'])
      is_new_entry = facebook_entry.new_record?

      attachments_data = post.dig('attachments', 'data') || []
      main_attachment = attachments_data.first || {}

      attachment_target_url = decode_facebook_url(main_attachment.dig('target', 'url'))
      attachment_url = decode_facebook_url(main_attachment['url'])
      permalink_url = decode_facebook_url(post['permalink_url']) if post['permalink_url']

      width = main_attachment.dig('media', 'image', 'width')
      height = main_attachment.dig('media', 'image', 'height')

      reaction_counts = build_reaction_counts(post)

      # ALWAYS update stats and data (for existing entries)
      facebook_entry.assign_attributes(
        page: page,
        posted_at: parse_timestamp(post['created_time']),
        fetched_at: Time.current,
        message: post['message'],
        permalink_url: permalink_url || attachment_target_url || attachment_url,
        attachment_type: main_attachment['type'],
        attachment_title: main_attachment['title'],
        attachment_description: main_attachment['description'],
        attachment_url: attachment_url,
        attachment_target_url: attachment_target_url,
        attachment_media_src: main_attachment.dig('media', 'image', 'src'),
        attachment_media_width: width.present? ? width.to_i : nil,
        attachment_media_height: height.present? ? height.to_i : nil,
        attachments_raw: attachments_data,
        comments_count: extract_total(post['comments']),
        share_count: numeric_value(post.dig('shares', 'count')),
        payload: post
      )

      facebook_entry.assign_attributes(reaction_counts)
      facebook_entry.reactions_total_count = reaction_counts.values.sum

      facebook_entry.save!

      if is_new_entry
        Rails.logger.info("[FacebookServices::FanpageCrawler] ✓ Created new post: #{facebook_entry.facebook_post_id}")
      else
        Rails.logger.debug("[FacebookServices::FanpageCrawler] ✓ Updated existing post: #{facebook_entry.facebook_post_id}")
      end

      # Link to Entry if matching URL is found (only for new or unlinked entries)
      link_to_entry(facebook_entry)

      # ALWAYS re-tag (to catch new tags added to system)
      tag_entry(facebook_entry, is_new: is_new_entry)

      facebook_entry
    rescue ActiveRecord::RecordInvalid => e
      Rails.logger.error("[FacebookServices::FanpageCrawler] Unable to persist post #{post['id']}: #{e.message}")
      nil
    end

    def link_to_entry(facebook_entry)
      # Skip if already linked or no URL
      return if facebook_entry.entry_id.present?
      return unless facebook_entry.has_external_url?

      url = facebook_entry.primary_url
      return if url.blank?

      # Skip Facebook internal URLs
      if url.include?('facebook.com/photo') || url.include?('facebook.com/watch') || url.include?('fb.watch')
        Rails.logger.debug("[FacebookServices::FanpageCrawler] Skipping Facebook internal URL for post #{facebook_entry.facebook_post_id}")
        return
      end

      # Try to find matching entry
      entry = find_entry_by_url(url)

      if entry
        facebook_entry.update(entry: entry)
        Rails.logger.info("[FacebookServices::FanpageCrawler] Linked post #{facebook_entry.facebook_post_id} to entry #{entry.id} (#{entry.url})")
      else
        Rails.logger.debug("[FacebookServices::FanpageCrawler] No matching entry found for URL: #{url}")
      end
    rescue StandardError => e
      # Log linking errors but don't fail the crawl
      Rails.logger.error("[FacebookServices::FanpageCrawler] Error linking post #{facebook_entry.facebook_post_id}: #{e.message}")
    end

    def find_entry_by_url(url)
      # Try different URL variations
      variations = normalize_url(url)

      variations.each do |variation|
        entry = Entry.find_by(url: variation)
        return entry if entry
      end

      nil
    end

    def normalize_url(url)
      return [] if url.blank?

      variations = []

      # 1. Exact URL
      variations << url

      # 2. Without query parameters or fragments
      clean_url = url.split('?').first.split('#').first
      variations << clean_url unless variations.include?(clean_url)

      # 3. Without trailing slash
      without_slash = clean_url.chomp('/')
      variations << without_slash unless variations.include?(without_slash)

      # 4. Protocol variations (http vs https)
      [url, clean_url, without_slash].each do |variant|
        if variant.start_with?('http://')
          https_variant = variant.sub('http://', 'https://')
          variations << https_variant unless variations.include?(https_variant)
        elsif variant.start_with?('https://')
          http_variant = variant.sub('https://', 'http://')
          variations << http_variant unless variations.include?(http_variant)
        end
      end

      variations.compact.uniq
    end

    def tag_entry(facebook_entry, is_new: false)
      # Extract tags from Facebook post text
      result = WebExtractorServices::ExtractFacebookEntryTags.call(facebook_entry.id)

      # If no tags found through text matching, try to inherit from linked entry
      if !result.success? && facebook_entry.entry.present? && facebook_entry.entry.tag_list.any?
        entry_tags = facebook_entry.entry.tag_list.dup
        entry_tags.delete('Facebook')
        entry_tags.delete('WhatsApp')

        # Smart tag change detection
        new_tags = entry_tags.sort
        current_tags = facebook_entry.tag_list.sort

        if new_tags != current_tags
          facebook_entry.tag_list = entry_tags
          facebook_entry.save!
          Rails.logger.info("[FacebookServices::FanpageCrawler] Tagged post #{facebook_entry.facebook_post_id} with inherited tags: #{entry_tags.join(', ')}")
        else
          Rails.logger.debug("[FacebookServices::FanpageCrawler] Tags unchanged for post #{facebook_entry.facebook_post_id}")
        end
        return
      end

      if result.success?
        tags = result.data.dup
        tags.delete('Facebook')
        tags.delete('WhatsApp')

        # Smart tag change detection
        new_tags = tags.sort
        current_tags = facebook_entry.tag_list.sort

        if new_tags != current_tags
          facebook_entry.tag_list = tags
          facebook_entry.save!
          if is_new
            Rails.logger.info("[FacebookServices::FanpageCrawler] Tagged new post #{facebook_entry.facebook_post_id} with tags: #{tags.join(', ')}")
          else
            Rails.logger.info("[FacebookServices::FanpageCrawler] Re-tagged post #{facebook_entry.facebook_post_id} with updated tags: #{tags.join(', ')}")
          end
        else
          Rails.logger.debug("[FacebookServices::FanpageCrawler] Tags unchanged for post #{facebook_entry.facebook_post_id}: #{tags.join(', ')}")
        end
      else
        Rails.logger.debug("[FacebookServices::FanpageCrawler] No tags found for post #{facebook_entry.facebook_post_id}: #{result.error}")
      end
    rescue StandardError => e
      # Log tagging errors but don't fail the crawl
      Rails.logger.error("[FacebookServices::FanpageCrawler] Error tagging post #{facebook_entry.facebook_post_id}: #{e.message}")
    end

    def build_reaction_counts(post)
      REACTION_TYPES.each_with_object({}) do |type, acc|
        acc[:"reactions_#{type}_count"] = extract_total(post["reactions_#{type}"])
      end
    end

    def extract_total(node)
      summary = node.is_a?(Hash) ? node['summary'] : nil
      value = summary ? summary['total_count'] : nil
      numeric_value(value)
    end

    def numeric_value(value)
      case value
      when String
        value.to_i
      when Numeric
        value.to_i
      else
        0
      end
    end

    def parse_timestamp(value)
      return if value.blank?

      Time.zone.parse(value)
    rescue ArgumentError
      nil
    end

    def decode_facebook_url(url)
      return if url.blank?

      uri = URI.parse(url)
      if uri.host&.include?('l.facebook.com') && uri.query.present?
        params = CGI.parse(uri.query)
        params['u']&.first || url
      else
        url
      end
    rescue URI::InvalidURIError
      url
    end

    # Wrapper method that handles retries with exponential backoff
    def call_api_with_retry(page_uid, cursor = nil)
      attempt = 0
      last_error = nil

      loop do
        attempt += 1

        begin
          return call_api(page_uid, cursor)
        rescue ApiError => e
          last_error = e

          # Check if it's a retryable error (timeout, network error, or connection reset)
          retryable = e.message.include?('timeout') ||
                      e.message.include?('Network error') ||
                      e.message.include?('connection') ||
                      e.message.include?('Connection reset')

          unless retryable
            # Non-retryable errors (auth errors, etc.) should fail immediately
            Rails.logger.error("[FacebookServices::FanpageCrawler] Non-retryable error: #{e.message}")
            raise e
          end

          # Check if we've exhausted retries
          if attempt >= MAX_RETRIES
            Rails.logger.error("[FacebookServices::FanpageCrawler] Max retries (#{MAX_RETRIES}) exceeded for page #{page_uid}")
            raise e
          end

          # Calculate exponential backoff delay
          delay = [INITIAL_RETRY_DELAY * (2**(attempt - 1)), MAX_RETRY_DELAY].min

          Rails.logger.warn("[FacebookServices::FanpageCrawler] Retry #{attempt}/#{MAX_RETRIES} for page #{page_uid} after #{delay}s (Error: #{e.message})")

          # Wait before retrying
          sleep(delay)
        end
      end
    end

    def call_api(page_uid, cursor = nil)
      # Validate token is present
      token = ENV.fetch('FACEBOOK_API_TOKEN') do
        raise ArgumentError, 'FACEBOOK_API_TOKEN environment variable is not set. Please add it to your .env file.'
      end

      api_url = "#{API_BASE_URL}/#{API_VERSION}/"
      token_param = "&access_token=#{token}"
      reactions = '%2Creactions.type(LIKE).limit(0).summary(total_count).as(reactions_like)%2Creactions.type(LOVE).limit(0).summary(total_count).as(reactions_love)%2Creactions.type(WOW).limit(0).summary(total_count).as(reactions_wow)%2Creactions.type(HAHA).limit(0).summary(total_count).as(reactions_haha)%2Creactions.type(SAD).limit(0).summary(total_count).as(reactions_sad)%2Creactions.type(ANGRY).limit(0).summary(total_count).as(reactions_angry)%2Creactions.type(THANKFUL).limit(0).summary(total_count).as(reactions_thankful)'
      comments = '%2Ccomments.limit(0).summary(total_count)'
      shares = '%2Cshares'
      limit = "&limit=#{API_PAGE_SIZE}"
      next_page = cursor ? "&after=#{cursor}" : ''

      url = "/#{page_uid}/posts?fields=id%2Cattachments%2Ccreated_time%2Cmessage%2Cpermalink_url"
      request = "#{api_url}#{url}#{shares}#{comments}#{reactions}#{limit}#{token_param}#{next_page}"

      # Make API call with timeout and error handling
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

      # Check for API-level errors
      if data['error']
        error_code = data['error']['code']
        error_message = data['error']['message']
        error_type = data['error']['type']

        # Handle rate limiting
        if RATE_LIMIT_ERROR_CODES.include?(error_code)
          wait_time = extract_wait_time(data['error']) || DEFAULT_WAIT_TIME
          Rails.logger.warn("[FacebookServices::FanpageCrawler] Rate limit hit (code: #{error_code}), waiting #{wait_time}s...")
          sleep(wait_time)
          return call_api(page_uid, cursor) # Retry after waiting
        end

        # Handle invalid/expired token
        if AUTH_ERROR_CODES.include?(error_code)
          Rails.logger.error("[FacebookServices::FanpageCrawler] Invalid access token: #{error_message}")
          raise ApiError, "Facebook API authentication failed: #{error_message}"
        end

        # Other API errors
        Rails.logger.error("[FacebookServices::FanpageCrawler] Facebook API error (code: #{error_code}, type: #{error_type}): #{error_message}")
        raise ApiError, "Facebook API error: #{error_message}"
      end

      # Check HTTP response status
      unless response.success?
        Rails.logger.error("[FacebookServices::FanpageCrawler] HTTP #{response.code}: #{response.body[0..500]}")
        raise ApiError, "Facebook API returned HTTP #{response.code}"
      end

      data
    rescue Net::OpenTimeout => e
      Rails.logger.error("[FacebookServices::FanpageCrawler] Connection timeout for page #{page_uid}: #{e.message}")
      raise ApiError, "Facebook API connection timeout"
    rescue Net::ReadTimeout => e
      Rails.logger.error("[FacebookServices::FanpageCrawler] Read timeout for page #{page_uid}: #{e.message}")
      raise ApiError, "Facebook API read timeout"
    rescue Timeout::Error => e
      Rails.logger.error("[FacebookServices::FanpageCrawler] Timeout error for page #{page_uid}: #{e.message}")
      raise ApiError, "Facebook API timeout"
    rescue JSON::ParserError
      Rails.logger.error("[FacebookServices::FanpageCrawler] Invalid JSON response: #{response&.body&.[](0..500)}")
      raise ApiError, "Invalid JSON from Facebook API"
    rescue SocketError, Errno::ECONNREFUSED, Errno::EHOSTUNREACH => e
      Rails.logger.error("[FacebookServices::FanpageCrawler] Network error: #{e.class} - #{e.message}")
      raise ApiError, "Network error connecting to Facebook API"
    rescue Errno::ETIMEDOUT => e
      Rails.logger.error("[FacebookServices::FanpageCrawler] Connection timed out for page #{page_uid}: #{e.message}")
      raise ApiError, "Facebook API connection timeout"
    rescue Errno::ECONNRESET => e
      Rails.logger.error("[FacebookServices::FanpageCrawler] Connection reset by peer for page #{page_uid}: #{e.message}")
      raise ApiError, "Facebook API connection reset"
    end

    # Extract wait time from rate limit error
    def extract_wait_time(error_data)
      # Try to extract wait time from error message (e.g., "Please retry your request in 60 seconds")
      message = error_data['error_user_msg'] || error_data['message'] || ''
      match = message.match(/(\d+)\s*seconds?/i)
      match ? match[1].to_i : nil
    end

    # Custom error class for API errors
    class ApiError < StandardError; end
  end
end

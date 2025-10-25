# frozen_string_literal: true

require 'httparty'
require 'json'

module TwitterServices
  # TwitterServices::GetPostsDataAuth
  #
  # This service fetches tweets using authenticated Twitter session credentials.
  # Unlike the guest token approach, this uses OAuth session tokens from a logged-in user.
  #
  # IMPORTANT NOTES:
  # - This requires valid session cookies (auth_token, ct0) from a logged-in Twitter account
  # - These tokens expire and must be refreshed/rotated frequently
  # - This approach is UNSTABLE and NOT officially supported by Twitter's API
  # - Use at your own risk - Twitter may block or ban accounts using this method
  # - Cookies can be obtained from browser DevTools while logged into Twitter
  #
  # Required ENV variables:
  # - TWITTER_AUTH_TOKEN: The auth_token cookie value from a logged-in session
  # - TWITTER_CT0_TOKEN: The ct0 (CSRF token) cookie value
  # - TWITTER_BEARER_TOKEN: The bearer token (can be the same as guest approach)
  #
  # Example usage:
  #   result = TwitterServices::GetPostsDataAuth.call('123456789')
  #   if result.success?
  #     tweets_data = result.data
  #   end
  #
  class GetPostsDataAuth < ApplicationService
    include HTTParty

    base_uri 'https://twitter.com/i/api'

    def initialize(user_id, max_requests: 1)
      @user_id = user_id
      @max_requests = max_requests # Number of paginated requests (each returns ~20 tweets)
      @bearer_token = ENV['TWITTER_BEARER_TOKEN'] || 'AAAAAAAAAAAAAAAAAAAAANRILgAAAAAAnNwIzUejRCOuH5E6I8xnZz4puTs=1Zv7ttfk8LF81IUq16cHjhLTvJu4FA33AGWWjCpTnA'
      @auth_token = ENV.fetch('TWITTER_AUTH_TOKEN', nil)
      @ct0_token = ENV.fetch('TWITTER_CT0_TOKEN', nil)
    end

    def call
      # Validate required tokens
      if @auth_token.blank? || @ct0_token.blank?
        return handle_error('Missing required authentication tokens (TWITTER_AUTH_TOKEN or TWITTER_CT0_TOKEN)')
      end

      all_data = []
      cursor = nil
      request_count = 0

      loop do
        response = self.class.get(
          '/graphql/E8Wq-_jFSaU7hxVcuOPR9g/UserTweets',
          headers: auth_headers,
          query: {
            variables: variables(cursor).to_json,
            features: features.to_json,
            fieldToggles: { withArticlePlainText: false }.to_json
          }
        )

        data = JSON.parse(response.body)

        unless response.success?
          error_message = data['errors']&.map { |e| e['message'] }
&.join(', ') || 'Unknown error'
          return handle_error("API Error: #{error_message}")
        end

        all_data << data
        request_count += 1

        # Extract cursor for next page
        cursor = extract_cursor(data)

        # Stop if no more pages or reached max requests
        break if cursor.nil? || request_count >= @max_requests

        # Random delay between 1-10 seconds to avoid rate limiting
        delay = rand(5..15)
        sleep(delay)
      end

      handle_success(all_data)
    rescue JSON::ParserError => e
      handle_error("JSON parsing failed: #{e.message}")
    rescue StandardError => e
      handle_error("Request failed: #{e.message}")
    end

    private

    def auth_headers
      {
        'Authorization' => "Bearer #{@bearer_token}",
        'x-csrf-token' => @ct0_token,
        'Cookie' => "auth_token=#{@auth_token}; ct0=#{@ct0_token}",
        'Content-Type' => 'application/json',
        'User-Agent' => 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
        'x-twitter-active-user' => 'yes',
        'x-twitter-client-language' => 'en'
      }
    end

    def variables(cursor = nil)
      vars = {
        userId: @user_id,
        count: 100,
        includePromotedContent: false,
        withQuickPromoteEligibilityTweetFields: true,
        withVoice: true,
        withV2Timeline: true
      }

      vars[:cursor] = cursor if cursor.present?
      vars
    end

    def extract_cursor(data)
      # Navigate through the response to find the bottom cursor
      # Try the newer timeline_v2 structure first
      instructions = data.dig('data', 'user', 'result', 'timeline_v2', 'timeline', 'instructions')

      # Fall back to older timeline structure
      instructions ||= data.dig('data', 'user', 'result', 'timeline', 'timeline', 'instructions')

      return unless instructions

      instructions.each do |instruction|
        # If we hit a terminate instruction, there are no more pages
        return nil if instruction['type'] == 'TimelineTerminateTimeline'

        next unless instruction['type'] == 'TimelineAddEntries'

        entries = instruction['entries']
        next unless entries

        # Look for the cursor entry at the bottom
        cursor_entry = entries.find { |entry| entry['entryId']&.start_with?('cursor-bottom') }
        next unless cursor_entry

        return cursor_entry.dig('content', 'value')
      end

      nil
    end

    def features
      {
        rweb_video_screen_enabled: false,
        payments_enabled: false,
        rweb_xchat_enabled: false,
        profile_label_improvements_pcf_label_in_post_enabled: true,
        rweb_tipjar_consumption_enabled: true,
        verified_phone_label_enabled: false,
        creator_subscriptions_tweet_preview_api_enabled: true,
        responsive_web_graphql_timeline_navigation_enabled: true,
        responsive_web_graphql_skip_user_profile_image_extensions_enabled: false,
        premium_content_api_read_enabled: false,
        communities_web_enable_tweet_community_results_fetch: true,
        c9s_tweet_anatomy_moderator_badge_enabled: true,
        responsive_web_grok_analyze_button_fetch_trends_enabled: false,
        responsive_web_grok_analyze_post_followups_enabled: false,
        responsive_web_jetfuel_frame: true,
        responsive_web_grok_share_attachment_enabled: true,
        articles_preview_enabled: true,
        responsive_web_edit_tweet_api_enabled: true,
        graphql_is_translatable_rweb_tweet_is_translatable_enabled: true,
        view_counts_everywhere_api_enabled: true,
        longform_notetweets_consumption_enabled: true,
        responsive_web_twitter_article_tweet_consumption_enabled: true,
        tweet_awards_web_tipping_enabled: false,
        responsive_web_grok_show_grok_translated_post: false,
        responsive_web_grok_analysis_button_from_backend: false,
        creator_subscriptions_quote_tweet_preview_enabled: false,
        freedom_of_speech_not_reach_fetch_enabled: true,
        standardized_nudges_misinfo: true,
        tweet_with_visibility_results_prefer_gql_limited_actions_policy_enabled: true,
        longform_notetweets_rich_text_read_enabled: true,
        longform_notetweets_inline_media_enabled: true,
        responsive_web_grok_image_annotation_enabled: true,
        responsive_web_grok_imagine_annotation_enabled: true,
        responsive_web_grok_community_note_auto_translation_is_enabled: false,
        responsive_web_enhance_cards_enabled: false
      }
    end
  end
end

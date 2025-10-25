# frozen_string_literal: true

require 'httparty'
require 'json'
require 'uri'

module TwitterServices
  class GetProfileData < ApplicationService
    include HTTParty

    base_uri 'https://api.x.com'

    def initialize(user_id)
      @user_id = user_id
      @bearer_token = 'AAAAAAAAAAAAAAAAAAAAANRILgAAAAAAnNwIzUejRCOuH5E6I8xnZz4puTs=1Zv7ttfk8LF81IUq16cHjhLTvJu4FA33AGWWjCpTnA'
      @guest_token = fetch_guest_token
    end

    def call
      return handle_error('Missing guest token') if @guest_token.nil?

      response = self.class.get(
        '/graphql/E8Wq-_jFSaU7hxVcuOPR9g/UserTweets',
        headers: {
          Authorization: "Bearer #{@bearer_token}",
          'x-guest-token': @guest_token,
          'Content-Type': 'application/json'
        },
        query: {
          variables: variables.to_json,
          features: features.to_json,
          fieldToggles: { withArticlePlainText: false }.to_json
        }
      )

      data = JSON.parse(response.body)
      if response.success?
        handle_success(data)
      else
        handle_error(data['errors'] || 'Unknown error')
      end
    rescue StandardError => e
      handle_error(e.message)
    end

    private

    def fetch_guest_token
      response = self.class.post(
        '/1.1/guest/activate.json',
        headers: { 'Authorization' => "Bearer #{@bearer_token}" }
      )

      JSON.parse(response.body)['guest_token'] if response.success?
    rescue StandardError
      nil
    end

    def variables
      {
        userId: @user_id,
        count: 100,
        includePromotedContent: true,
        withQuickPromoteEligibilityTweetFields: true,
        withVoice: true
      }
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

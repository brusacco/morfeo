# frozen_string_literal: true

module TwitterServices
  class UpdateProfile < ApplicationService
    def initialize(user_id)
      @user_id = user_id
    end

    def call
      response = TwitterServices::GetProfileData.call(@user_id)

      return handle_error(response.error) unless response.success?

      profile_data = extract_profile_data(response.data)
      handle_success(profile_data)
    rescue StandardError => e
      handle_error(e.message)
    end

    private

    def extract_profile_data(data)
      # Navigate the Twitter API response structure to get user data from timeline
      # The response structure is: data['user']['result']['timeline']['timeline']['instructions']
      timeline = data.dig('user', 'result', 'timeline', 'timeline', 'instructions') || []

      # Find an entry with user data (usually in the first tweet)
      user_result = nil
      timeline.each do |instruction|
        entries = instruction['entries'] || []
        entries.each do |entry|
          tweet_result = entry.dig('content', 'itemContent', 'tweet_results', 'result')
          next unless tweet_result

          user_result = tweet_result.dig('core', 'user_results', 'result')
          break if user_result
        end
        break if user_result
      end

      return {} unless user_result

      legacy = user_result['legacy'] || {}
      core = user_result['core'] || {}
      avatar = user_result['avatar'] || {}

      {
        uid: user_result['rest_id'] || @user_id,
        username: legacy['screen_name'] || core['screen_name'],
        name: legacy['name'] || core['name'],
        description: legacy['description'],
        followers: legacy['followers_count'] || 0,
        verified: user_result['is_blue_verified'] || legacy['verified'] || false,
        picture: (avatar['image_url'] || legacy['profile_image_url_https'])&.gsub('_normal', '_400x400')
      }
    end
  end
end

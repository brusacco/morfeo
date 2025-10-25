# frozen_string_literal: true

module TwitterServices
  class ProcessPosts < ApplicationService
    def initialize(profile_uid)
      @profile_uid = profile_uid
    end

    def call
      profile = TwitterProfile.find_by!(uid: @profile_uid)
      response = TwitterServices::GetPostsData.call(@profile_uid)

      return handle_error(response.error) unless response.success?

      data = response.data
      tweets = extract_tweets(data)

      saved_posts =
        tweets.filter_map do |tweet_data|
          persist_post(profile, tweet_data)
        end

      handle_success({ posts: saved_posts, count: saved_posts.count })
    rescue StandardError => e
      handle_error(e.message)
    end

    private

    def extract_tweets(data)
      timeline = data.dig('data', 'user', 'result', 'timeline', 'timeline', 'instructions') || []
      tweets = []

      timeline.each do |instruction|
        entries = instruction['entries'] || []
        entries.each do |entry|
          next unless entry['entryId']&.start_with?('tweet-')

          tweet_result = entry.dig('content', 'itemContent', 'tweet_results', 'result')
          next unless tweet_result

          tweets << tweet_result
        end
      end

      tweets
    end

    def persist_post(profile, tweet_data)
      tweet_id = tweet_data['rest_id']
      return unless tweet_id

      twitter_post = TwitterPost.find_or_initialize_by(tweet_id: tweet_id)

      legacy = tweet_data['legacy'] || {}
      views = tweet_data.dig('views', 'count')

      # Check if it's a retweet or quote tweet
      is_retweet = legacy['retweeted_status_result'].present?
      is_quote = legacy['is_quote_status'] || false

      # Build tweet URL
      username = profile.username || profile.uid
      permalink_url = "https://twitter.com/#{username}/status/#{tweet_id}"

      twitter_post.assign_attributes(
        twitter_profile: profile,
        posted_at: parse_timestamp(legacy['created_at']),
        fetched_at: Time.current,
        text: legacy['full_text'],
        permalink_url: permalink_url,
        quote_count: legacy['quote_count'] || 0,
        reply_count: legacy['reply_count'] || 0,
        retweet_count: legacy['retweet_count'] || 0,
        favorite_count: legacy['favorite_count'] || 0,
        views_count: views.present? ? Integer(views, 10) : 0,
        bookmark_count: legacy['bookmark_count'] || 0,
        lang: legacy['lang'],
        source: extract_source(legacy['source']),
        is_retweet: is_retweet,
        is_quote: is_quote,
        payload: tweet_data
      )

      twitter_post.save!
      twitter_post
    rescue ActiveRecord::RecordInvalid => e
      Rails.logger.error("[TwitterServices::ProcessPosts] Unable to persist tweet #{tweet_id}: #{e.message}")
      nil
    end

    def parse_timestamp(value)
      return if value.blank?

      Time.zone.parse(value)
    rescue ArgumentError
      nil
    end

    def extract_source(source_html)
      return if source_html.blank?

      # Extract text from HTML anchor tag
      source_html.match(/>([^<]+)</)&.captures&.first || source_html
    end
  end
end

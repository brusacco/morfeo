# frozen_string_literal: true

module TwitterServices
  class ProcessPosts < ApplicationService
    def initialize(profile_uid, stop_on_duplicates: true, update_existing: false)
      @profile_uid = profile_uid
      @stop_on_duplicates = stop_on_duplicates
      @update_existing = update_existing
    end

    def call
      profile = TwitterProfile.find_by!(uid: @profile_uid)

      # Use authenticated API if credentials are available, otherwise fall back to guest token
      response =
        if ENV['TWITTER_AUTH_TOKEN'].present? && ENV['TWITTER_CT0_TOKEN'].present?
          TwitterServices::GetPostsDataAuth.call(@profile_uid)
        else
          # TwitterServices::GetPostsData.call(@profile_uid)
        end

      return handle_error(response.error) unless response.success?

      # Handle both single response (guest API) and array of responses (authenticated API with pagination)
      data_array = response.data.is_a?(Array) ? response.data : [response.data]
      all_tweets = []
      all_saved_posts = []
      stop_early = false

      # Extract tweets from each paginated response
      data_array.each_with_index do |data, page_index|
        Rails.logger.info("[TwitterServices::ProcessPosts] Crawling page #{page_index + 1} for #{profile.username}")
        puts "  -> Crawling page #{page_index + 1}..."

        tweets = extract_tweets(data)
        page_saved = []

        tweets.each do |tweet_data|
          saved_post = persist_post(profile, tweet_data, @update_existing)
          page_saved << saved_post if saved_post
        end

        all_tweets.concat(tweets)
        all_saved_posts.concat(page_saved)

        # Stop early if we're on page 2+ and found mostly duplicates (< 10% new tweets)
        # Only applies if stop_on_duplicates is enabled
        next unless @stop_on_duplicates && page_index > 0 && tweets.any?

        new_tweets_ratio = Float(page_saved.count) / tweets.count
        next unless new_tweets_ratio < 0.1

        Rails.logger.info("[TwitterServices::ProcessPosts] Stopping pagination early for #{profile.username}: only #{page_saved.count}/#{tweets.count} new tweets on page #{page_index + 1}")
        stop_early = true
        break
      end

      message = stop_early ? 'Stopped early (found mostly duplicates)' : 'Completed all pages'
      handle_success({ posts: all_saved_posts, count: all_saved_posts.count, message: message })
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

    def persist_post(profile, tweet_data, update_existing = false)
      tweet_id = tweet_data['rest_id']
      return unless tweet_id

      twitter_post = TwitterPost.find_or_initialize_by(tweet_id: tweet_id)

      # Return nil if this tweet already exists and we're not updating
      return unless twitter_post.new_record? || update_existing

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
      
      # Tag the tweet immediately after saving
      tag_post(twitter_post)
      
      twitter_post
    rescue ActiveRecord::RecordInvalid => e
      Rails.logger.error("[TwitterServices::ProcessPosts] Unable to persist tweet #{tweet_id}: #{e.message}")
      nil
    end

    def tag_post(twitter_post)
      result = TwitterServices::ExtractTags.call(twitter_post.id)

      # If no tags found through text matching, try to inherit from linked entry
      if !result.success? && twitter_post.entry.present? && twitter_post.entry.tag_list.any?
        entry_tags = twitter_post.entry.tag_list.dup
        entry_tags.delete('Twitter')
        
        twitter_post.tag_list = entry_tags
        twitter_post.save!
        Rails.logger.info("[TwitterServices::ProcessPosts] Tagged tweet #{twitter_post.tweet_id} with inherited tags: #{entry_tags.join(', ')}")
        return
      end

      if result.success?
        tags = result.data.dup
        tags.delete('Twitter')
        
        # Note: ExtractTags already saves the tags, but we'll ensure cleanup
        Rails.logger.info("[TwitterServices::ProcessPosts] Tagged tweet #{twitter_post.tweet_id} with tags: #{tags.join(', ')}")
      else
        Rails.logger.debug("[TwitterServices::ProcessPosts] No tags found for tweet #{twitter_post.tweet_id}: #{result.error}")
      end
    rescue StandardError => e
      # Log tagging errors but don't fail the crawl
      Rails.logger.error("[TwitterServices::ProcessPosts] Error tagging tweet #{twitter_post.tweet_id}: #{e.message}")
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

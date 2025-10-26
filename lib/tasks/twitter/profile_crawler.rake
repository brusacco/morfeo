# frozen_string_literal: true

namespace :twitter do
  desc 'Twitter Profile Posts Crawler'
  task profile_crawler: :environment do
    TwitterProfile.find_each do |profile|
      puts "Processing Twitter Profile: #{profile.name || profile.username} (@#{profile.username})"
      puts "  Current tweets in DB: #{profile.twitter_posts.count}"
      puts "  Latest tweet in DB: #{profile.twitter_posts.order(posted_at: :desc).first&.posted_at || 'None'}"

      # Retry logic for rate limits
      max_retries = 2
      retry_count = 0
      response = nil

      loop do
        response = TwitterServices::ProcessPosts.call(profile.uid)

        # Check if error is rate limit related
        if !response.success? && (response.error.to_s.include?('Rate') || response.error.to_s.include?('429'))
          retry_count += 1
          if retry_count <= max_retries
            puts "  -> Rate limit hit, waiting 5 seconds before retry (attempt #{retry_count}/#{max_retries})..."
            sleep(5)
            next
          else
            puts "  -> Max retries reached, skipping #{profile.username}"
            break
          end
        end

        break
      end

      unless response.success?
        puts "  -> Error crawling #{profile.username}: #{response.error}"
        next
      end

      data = response.data || {}
      posts = data[:posts] || []
      message = data[:message]

      if posts.empty?
        status = message == 'Stopped early (found mostly duplicates)' ? '(stopped early - duplicates)' : ''
        puts "  -> No new tweets found for #{profile.username} #{status}"
      else
        new_count = posts.count
        total_count = profile.twitter_posts.count
        latest = profile.twitter_posts.order(posted_at: :desc).first

        status_msg = message == 'Stopped early (found mostly duplicates)' ? ' (stopped early)' : ''
        puts "  -> Stored #{new_count} new tweets for #{profile.username}#{status_msg}"
        puts "  -> Total tweets now: #{total_count}"
        puts "  -> Latest tweet: #{latest.posted_at}" if latest

        # Show the 5 most recent
        posts.sort_by(&:posted_at).reverse.first(5).each do |post|
          puts "    - Tweet #{post.tweet_id} (#{post.posted_at})"
        end
      end
      puts '---------------------------------------------------'

      # Sleep between profiles to avoid rate limiting
      sleep(rand(3..8))
    end
  end
end

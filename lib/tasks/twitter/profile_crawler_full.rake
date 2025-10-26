# frozen_string_literal: true

namespace :twitter do
  desc 'Twitter Profile Posts Crawler - Full Crawl (fetches all pages without stopping on duplicates)'
  task profile_crawler_full: :environment do
    puts "Starting FULL Twitter Profile Crawler"
    puts "This will fetch all available pages regardless of duplicates"
    puts "AND update engagement metrics for existing tweets"
    puts "---------------------------------------------------"

    TwitterProfile.find_each do |profile|
      puts "Processing Twitter Profile: #{profile.name || profile.username} (@#{profile.username})"
      puts "  Current tweets in DB: #{profile.twitter_posts.count}"
      puts "  Latest tweet in DB: #{profile.twitter_posts.order(posted_at: :desc).first&.posted_at || 'None'}"

      # Retry logic for rate limits
      max_retries = 3
      retry_count = 0
      response = nil

      loop do
        # Call with stop_on_duplicates: false and update_existing: true to fetch all pages and update metrics
        response = TwitterServices::ProcessPosts.call(profile.uid, stop_on_duplicates: false, update_existing: true)

        # Check if error is rate limit related
        if !response.success? && (response.error.to_s.include?('Rate') || response.error.to_s.include?('429'))
          retry_count += 1
          if retry_count <= max_retries
            puts "  -> Rate limit hit, waiting #{retry_count * 5} seconds before retry (attempt #{retry_count}/#{max_retries})..."
            sleep(retry_count * 5)
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

      if posts.empty?
        puts "  -> No tweets found for #{profile.username}"
      else
        new_count = posts.count
        total_count = profile.twitter_posts.count
        latest = profile.twitter_posts.order(posted_at: :desc).first

        puts "  -> Processed #{new_count} tweets for #{profile.username} (full crawl with metrics update)"
        puts "  -> Total tweets now: #{total_count}"
        puts "  -> Latest tweet: #{latest.posted_at}" if latest

        # Show the 5 most recent
        posts.sort_by(&:posted_at).reverse.first(5).each do |post|
          puts "    - Tweet #{post.tweet_id} (#{post.posted_at}) - ❤️ #{post.favorite_count} | 🔁 #{post.retweet_count} | 👁️ #{post.views_count}"
        end
      end
      puts '---------------------------------------------------'

      # Sleep between profiles to avoid rate limiting
      sleep(rand(10..20))
    end
  end
end

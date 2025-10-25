# frozen_string_literal: true

namespace :twitter do
  desc 'Twitter Profile Posts Crawler'
  task profile_crawler: :environment do
    TwitterProfile.find_each do |profile|
      puts "Processing Twitter Profile: #{profile.name || profile.username} (@#{profile.username})"
      puts "  Current tweets in DB: #{profile.twitter_posts.count}"
      puts "  Latest tweet in DB: #{profile.twitter_posts.order(posted_at: :desc).first&.posted_at || 'None'}"

      response = TwitterServices::ProcessPosts.call(profile.uid)

      unless response.success?
        puts "  -> Error crawling #{profile.username}: #{response.error}"
        next
      end

      data = response.data || {}
      posts = data[:posts] || []

      if posts.empty?
        puts "  -> No new tweets found for #{profile.username}"
      else
        new_count = posts.count
        total_count = profile.twitter_posts.count
        latest = profile.twitter_posts.order(posted_at: :desc).first

        puts "  -> Stored #{new_count} new tweets for #{profile.username}"
        puts "  -> Total tweets now: #{total_count}"
        puts "  -> Latest tweet: #{latest.posted_at}" if latest

        # Show the 5 most recent
        posts.sort_by(&:posted_at).reverse.first(5).each do |post|
          puts "    - Tweet #{post.tweet_id} (#{post.posted_at})"
        end
      end
      puts '---------------------------------------------------'
    end
  end
end

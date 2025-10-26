# frozen_string_literal: true

namespace :twitter do
  desc 'Tag Twitter posts using existing Tag vocabulary'
  task post_tagger: :environment do
    scope = TwitterPost.includes(:entry).where(posted_at: 7.days.ago..Time.current).order(posted_at: :desc)

    scope.find_each do |twitter_post|
      result = TwitterServices::ExtractTags.call(twitter_post.id)

      unless result.success?
        puts "Error tagging tweet #{twitter_post.tweet_id}: #{result.error}"
        next
      end

      # Remove "Twitter" tag if present
      result.data.delete('Twitter')

      puts "Tweet #{twitter_post.tweet_id}"
      puts "Tags: #{result.data.join(', ')}"
      if twitter_post.entry.present?
        puts "Linked to entry: #{twitter_post.entry.present? ? "Yes (#{twitter_post.entry.url})" : 'No'}"
      end
      puts "Posted: #{twitter_post.posted_at}"
      puts '---------------------------------------------------'
    rescue StandardError => e
      puts "Unexpected error tagging tweet #{twitter_post.tweet_id}: #{e.message}"
      sleep 1
      next
    end
  end
end

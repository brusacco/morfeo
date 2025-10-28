# frozen_string_literal: true

namespace :twitter do
  desc 'Tag Twitter posts using existing Tag vocabulary'
  task post_tagger: :environment do
    scope = TwitterPost.includes(:entry).where(posted_at: 7.days.ago..Time.current).order(posted_at: :desc)

    linked_inheritance_count = 0
    total_processed = 0
    error_count = 0

    scope.find_each do |twitter_post|
      total_processed += 1

      result = TwitterServices::ExtractTags.call(twitter_post.id)

      # If no tags found through text matching, check if we have a linked entry
      if !result.success? && twitter_post.entry.present? && twitter_post.entry.tag_list.any?
        # Inherit tags from linked entry even if text matching failed
        entry_tags = twitter_post.entry.tag_list.dup # Use dup to avoid modifying the original
        entry_tags.delete('Twitter')

        twitter_post.tag_list = entry_tags
        twitter_post.save!
        linked_inheritance_count += 1

        puts "Tweet #{twitter_post.tweet_id}"
        puts "Tags: #{entry_tags.join(', ')}"
        puts "Linked to entry: Yes (tags inherited from entry - #{twitter_post.entry.url})"
        puts "Posted: #{twitter_post.posted_at}"
        puts '---------------------------------------------------'
        next
      end

      unless result.success?
        puts "Error tagging tweet #{twitter_post.tweet_id}: #{result.error}"
        error_count += 1
        next
      end

      # Remove "Twitter" tag if present
      result.data.delete('Twitter')

      puts "Tweet #{twitter_post.tweet_id}"
      puts "Tags: #{result.data.join(', ')}"
      puts "Linked to entry: Yes (#{twitter_post.entry.url})" if twitter_post.entry.present?
      puts "Posted: #{twitter_post.posted_at}"
      puts '---------------------------------------------------'
    rescue ActiveRecord::RecordInvalid => e
      puts "Validation error for tweet #{twitter_post.tweet_id}: #{e.message}"
      error_count += 1
      next
    rescue StandardError => e
      puts "Unexpected error tagging tweet #{twitter_post.tweet_id}: #{e.message}"
      error_count += 1
      sleep 1
      next
    end

    puts "\n=== Summary ==="
    puts "Total processed: #{total_processed}"
    puts "Tweets with entry tag inheritance: #{linked_inheritance_count}"
    puts "Errors encountered: #{error_count}"

    if total_processed.positive?
      success_rate = (Float(total_processed - error_count) / total_processed * 100).round(2)
      puts "Success rate: #{success_rate}%"
    end
  end
end

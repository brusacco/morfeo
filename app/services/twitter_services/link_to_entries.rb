# frozen_string_literal: true

module TwitterServices
  # Links TwitterPosts to Entries by matching URLs
  #
  # This service finds tweets that contain external URLs and attempts to match them
  # with entries in the database by comparing the tweet's primary URL with entry URLs.
  #
  # Example usage:
  #   result = TwitterServices::LinkToEntries.call
  #   if result.success?
  #     puts "Linked #{result.data[:linked_count]} tweets to entries"
  #   end
  #
  class LinkToEntries < ApplicationService
    def initialize(scope: TwitterPost.where(entry_id: nil))
      @scope = scope
    end

    def call
      linked_count = 0
      processed_count = 0
      skipped_count = 0
      debug_count = 0

      @scope.find_each do |twitter_post|
        processed_count += 1

        # Debug first 3 tweets to see what's happening
        if debug_count < 3
          Rails.logger.info("[TwitterServices::LinkToEntries] DEBUG Tweet #{twitter_post.tweet_id}")
          Rails.logger.info("  Payload class: #{twitter_post.payload.class}")
          Rails.logger.info("  Payload present: #{twitter_post.payload.present?}")
          Rails.logger.info("  Has external URL: #{twitter_post.has_external_url?}")
          Rails.logger.info("  External URLs: #{twitter_post.external_urls.inspect}")
          debug_count += 1
        end

        # Skip tweets without external URLs
        unless twitter_post.has_external_url?
          skipped_count += 1
          next
        end

        # Try to find matching entry
        primary_url = twitter_post.primary_url
        next unless primary_url

        # Try exact match first
        entry = Entry.find_by(url: primary_url)

        # If no exact match, try without query parameters or fragments
        unless entry
          clean_url = primary_url.split('?').first.split('#').first
          entry = Entry.find_by(url: clean_url)
        end

        # Link if found
        if entry
          twitter_post.update(entry: entry)
          linked_count += 1

          Rails.logger.info("[TwitterServices::LinkToEntries] Linked tweet #{twitter_post.tweet_id} to entry #{entry.id}")
        end
      end

      handle_success({ linked_count: linked_count, processed_count: processed_count, skipped_count: skipped_count })
    rescue StandardError => e
      handle_error("Failed to link tweets to entries: #{e.message}")
    end
  end
end

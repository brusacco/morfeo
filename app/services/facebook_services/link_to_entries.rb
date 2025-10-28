# frozen_string_literal: true

module FacebookServices
  # Links FacebookEntries to Entries by matching URLs
  #
  # This service finds Facebook posts that contain external URLs and attempts to match them
  # with entries in the database by comparing the post's attachment URLs with entry URLs.
  #
  # Example usage:
  #   result = FacebookServices::LinkToEntries.call
  #   if result.success?
  #     puts "Linked #{result.data[:linked_count]} Facebook posts to entries"
  #   end
  #
  class LinkToEntries < ApplicationService
    def initialize(scope: FacebookEntry.where(entry_id: nil))
      @scope = scope
    end

    def call
      linked_count = 0
      processed_count = 0
      skipped_count = 0
      debug_count = 0

      @scope.find_each do |facebook_entry|
        processed_count += 1

        # Debug first 3 posts to see what's happening
        if debug_count < 3
          Rails.logger.info("[FacebookServices::LinkToEntries] DEBUG Post #{facebook_entry.facebook_post_id}")
          Rails.logger.info("  Attachment target URL: #{facebook_entry.attachment_target_url.inspect}")
          Rails.logger.info("  Attachment URL: #{facebook_entry.attachment_url.inspect}")
          Rails.logger.info("  Has external URL: #{facebook_entry.has_external_url?}")
          Rails.logger.info("  Primary URL: #{facebook_entry.primary_url.inspect}")
          debug_count += 1
        end

        # Skip posts without external URLs
        unless facebook_entry.has_external_url?
          skipped_count += 1
          next
        end

        # Use model method to find and link entry
        next if facebook_entry.primary_url.blank?

        matching_entry = facebook_entry.find_matching_entry
        next unless matching_entry

        # Link with transaction safety
        ActiveRecord::Base.transaction do
          facebook_entry.update!(entry: matching_entry)
          linked_count += 1

          Rails.logger.info(
            "[FacebookServices::LinkToEntries] Linked post #{facebook_entry.facebook_post_id} " \
            "to entry #{matching_entry.id} (#{matching_entry.url})"
          )
        end
      rescue ActiveRecord::RecordInvalid => e
        Rails.logger.error(
          "[FacebookServices::LinkToEntries] Failed to link post #{facebook_entry.facebook_post_id}: #{e.message}"
        )
      end

      handle_success({ linked_count: linked_count, processed_count: processed_count, skipped_count: skipped_count })
    rescue StandardError => e
      handle_error("Failed to link Facebook posts to entries: #{e.message}")
    end
  end
end

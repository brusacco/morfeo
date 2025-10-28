# frozen_string_literal: true

module FacebookServices
  # Links FacebookEntries to Entries by matching URLs
  #
  # This service finds Facebook posts that contain external URLs and attempts to match them
  # with entries in the database by comparing the post's attachment URLs with entry URLs.
  #
  # Optimized approach:
  # 1. Load all Entry URLs into memory (hash lookup is O(1))
  # 2. Process Facebook posts in batches
  # 3. Skip posts without URLs upfront
  #
  # Example usage:
  #   result = FacebookServices::LinkToEntries.call
  #   if result.success?
  #     puts "Linked #{result.data[:linked_count]} Facebook posts to entries"
  #   end
  #
  class LinkToEntries < ApplicationService
    BATCH_SIZE = 1000

    def initialize(scope: FacebookEntry.where(entry_id: nil))
      @scope = scope
    end

    def call
      linked_count = 0
      processed_count = 0
      skipped_count = 0

      # Pre-load all Entry URLs into a hash for O(1) lookup
      # Key: normalized URL, Value: Entry ID
      Rails.logger.info('[FacebookServices::LinkToEntries] Loading Entry URLs into memory...')
      entry_url_map = build_entry_url_map
      Rails.logger.info("[FacebookServices::LinkToEntries] Loaded #{entry_url_map.keys.count} unique Entry URL variations")

      # Only process posts that have external URLs
      posts_with_urls = @scope.with_url
      total_to_process = posts_with_urls.count
      Rails.logger.info("[FacebookServices::LinkToEntries] Processing #{total_to_process} Facebook posts with URLs...")

      posts_with_urls.find_in_batches(batch_size: BATCH_SIZE) do |batch|
        batch.each do |facebook_entry|
          processed_count += 1

          # Log progress every 1000 posts
          if processed_count % 1000 == 0
            Rails.logger.info(
              "[FacebookServices::LinkToEntries] Progress: #{processed_count}/#{total_to_process} " \
              "(#{linked_count} linked)"
            )
          end

          # Get primary URL
          url = facebook_entry.primary_url
          next if url.blank?

          # Skip Facebook internal URLs
          if url.include?('facebook.com/photo') || url.include?('facebook.com/watch') || url.include?('fb.watch')
            skipped_count += 1
            next
          end

          # Find matching entry using pre-loaded hash
          entry_id = find_entry_id_in_map(url, entry_url_map)
          next unless entry_id

          # Link with transaction safety
          begin
            ActiveRecord::Base.transaction do
              facebook_entry.update!(entry_id: entry_id)
              linked_count += 1
            end
          rescue ActiveRecord::RecordInvalid => e
            Rails.logger.error(
              "[FacebookServices::LinkToEntries] Failed to link post #{facebook_entry.facebook_post_id}: #{e.message}"
            )
          end
        end
      end

      handle_success({ linked_count: linked_count, processed_count: processed_count, skipped_count: skipped_count })
    rescue StandardError => e
      handle_error("Failed to link Facebook posts to entries: #{e.message}")
    end

    private

    # Build a hash of all Entry URLs with their variations for fast lookup
    # Returns: { "https://site.com/article" => entry_id, "http://site.com/article" => entry_id, ... }
    def build_entry_url_map
      map = {}
      Entry.select(:id, :url).find_each do |entry|
        next if entry.url.blank?

        # Generate all URL variations for this entry
        variations = normalize_url(entry.url)
        variations.each do |variation|
          # Store entry_id for each variation (first match wins if duplicates)
          map[variation] ||= entry.id
        end
      end
      map
    end

    # Find entry ID in the pre-loaded map using URL variations
    def find_entry_id_in_map(url, map)
      variations = normalize_url(url)
      variations.each do |variation|
        entry_id = map[variation]
        return entry_id if entry_id
      end
      nil
    end

    # Normalize URL to try different variations for matching
    # Same logic as FacebookEntry model method
    def normalize_url(url)
      return [] if url.blank?

      variations = []

      # 1. Exact URL
      variations << url

      # 2. Without query parameters or fragments
      clean_url = url.split('?').first.split('#').first
      variations << clean_url unless variations.include?(clean_url)

      # 3. Without trailing slash
      without_slash = clean_url.chomp('/')
      variations << without_slash unless variations.include?(without_slash)

      # 4. Protocol variations (http vs https)
      [url, clean_url, without_slash].each do |variant|
        if variant.start_with?('http://')
          https_variant = variant.sub('http://', 'https://')
          variations << https_variant unless variations.include?(https_variant)
        elsif variant.start_with?('https://')
          http_variant = variant.sub('https://', 'http://')
          variations << http_variant unless variations.include?(http_variant)
        end
      end

      # 5. WWW variations
      if url.include?('www.')
        variations << url.sub('www.', '')
        variations << clean_url.sub('www.', '')
      elsif url.match?(%r{\Ahttps?://(?!www\.)})
        # Try adding www
        with_www = url.sub(%r{(https?://)}i, '\1www.')
        variations << with_www unless variations.include?(with_www)
      end

      variations.compact.uniq
    end
  end
end

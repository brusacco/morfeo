# frozen_string_literal: true

namespace :facebook do
  desc 'Tag Facebook entries using existing Tag vocabulary'
  task entry_tagger: :environment do
    scope = FacebookEntry.includes(:entry).where(posted_at: 7.days.ago..Time.current).order(posted_at: :desc)

    linked_inheritance_count = 0
    total_processed = 0
    error_count = 0

    scope.find_each do |facebook_entry|
      total_processed += 1

      # if facebook_entry.tags.any?
      #   puts "Skipping #{facebook_entry.facebook_post_id}: already tagged"
      #   next
      # end

      result = WebExtractorServices::ExtractFacebookEntryTags.call(facebook_entry.id)

      # If no tags found through text matching, check if we have a linked entry
      if !result.success? && facebook_entry.entry.present? && facebook_entry.entry.tag_list.any?
        # Inherit tags from linked entry even if text matching failed
        entry_tags = facebook_entry.entry.tag_list.dup # Use dup to avoid modifying the original
        entry_tags.delete('Facebook')
        entry_tags.delete('WhatsApp')

        facebook_entry.tag_list = entry_tags
        facebook_entry.save!
        linked_inheritance_count += 1

        puts facebook_entry.facebook_post_id
        puts facebook_entry.tag_list
        puts facebook_entry.posted_at
        puts 'Entry linked: Yes (tags inherited from entry)'
        puts '---------------------------------------------------'
        next
      end

      unless result.success?
        puts "Error tagging #{facebook_entry.facebook_post_id}: #{result.error}"
        error_count += 1
        next
      end

      # Remove "Facebook" and "WhatsApp" tags if present
      result.data.delete('Facebook')
      result.data.delete('WhatsApp')

      facebook_entry.tag_list = result.data
      facebook_entry.save!
      # facebook_entry.touch

      puts facebook_entry.facebook_post_id
      puts facebook_entry.tag_list
      puts facebook_entry.posted_at
      puts "Entry linked: #{facebook_entry.entry_id.present? ? 'Yes' : 'No'}"
      puts '---------------------------------------------------'
    rescue ActiveRecord::RecordInvalid => e
      puts "Validation error for #{facebook_entry.facebook_post_id}: #{e.message}"
      error_count += 1
      next
    rescue StandardError => e
      puts "Unexpected error tagging #{facebook_entry.facebook_post_id}: #{e.message}"
      error_count += 1
      sleep 1
      next
    end

    puts "\n=== Summary ==="
    puts "Total processed: #{total_processed}"
    puts "Posts with entry tag inheritance: #{linked_inheritance_count}"
    puts "Errors encountered: #{error_count}"

    if total_processed.positive?
      success_rate = (Float(total_processed - error_count) / total_processed * 100).round(2)
      puts "Success rate: #{success_rate}%"
    end
  end
end

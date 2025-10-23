# frozen_string_literal: true

namespace :facebook do
  desc 'Tag Facebook entries using existing Tag vocabulary'
  task entry_tagger: :environment do
    scope = FacebookEntry.where(posted_at: 3.months.ago..Time.current)

    scope.find_each do |facebook_entry|
      # if facebook_entry.tags.any?
      #   puts "Skipping #{facebook_entry.facebook_post_id}: already tagged"
      #   next
      # end

      result = WebExtractorServices::ExtractFacebookEntryTags.call(facebook_entry.id)

      unless result.success?
        puts "Error tagging #{facebook_entry.facebook_post_id}: #{result.error}"
        next
      end

      facebook_entry.tag_list = result.data
      facebook_entry.save!
      facebook_entry.touch

      puts facebook_entry.facebook_post_id
      puts facebook_entry.tag_list
      puts '---------------------------------------------------'
    rescue StandardError => e
      puts "Unexpected error tagging #{facebook_entry.facebook_post_id}: #{e.message}"
      sleep 1
      next
    end
  end
end

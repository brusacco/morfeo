# frozen_string_literal: true

namespace :twitter do
  desc 'Link Twitter posts to Entries by matching URLs'
  task link_to_entries: :environment do
    puts 'Starting to link Twitter posts to Entries...'
    puts ''

    # Count tweets without entry links
    unlinked = TwitterPost.where(entry_id: nil).count
    total = TwitterPost.count

    puts "Total tweets: #{total}"
    puts "Unlinked tweets: #{unlinked}"
    puts "Already linked: #{total - unlinked}"
    puts ''

    result = TwitterServices::LinkToEntries.call

    if result.success?
      data = result.data
      puts '✅ Linking completed!'
      puts ''
      puts "Processed: #{data[:processed_count]} tweets"
      puts "Linked: #{data[:linked_count]} tweets"
      puts "Skipped (no URLs): #{data[:skipped_count]} tweets"
      puts ''

      # Show updated stats
      now_linked = TwitterPost.where.not(entry_id: nil).count
      puts "Total now linked: #{now_linked} (#{(now_linked.to_f / total * 100).round(2)}%)"
    else
      puts "❌ Error: #{result.error}"
    end
  end
end

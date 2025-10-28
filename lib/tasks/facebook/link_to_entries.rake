# frozen_string_literal: true

namespace :facebook do
  desc 'Link Facebook posts to Entry records by matching URLs'
  task link_to_entries: :environment do
    puts '=' * 80
    puts 'Starting Facebook to Entry linking process...'
    puts '=' * 80

    unlinked_count = FacebookEntry.where(entry_id: nil).count
    puts "\nUnlinked Facebook posts: #{unlinked_count}"

    if unlinked_count.zero?
      puts 'No unlinked posts found. Exiting.'
      next
    end

    result = FacebookServices::LinkToEntries.call

    if result.success?
      data = result.data
      puts "\n✅ Success!"
      puts "Processed: #{data[:processed_count]} posts"
      puts "Linked: #{data[:linked_count]} posts"
      puts "Skipped (no URL): #{data[:skipped_count]} posts"

      if data[:processed_count] > 0
        linking_rate = (Float(data[:linked_count]) / data[:processed_count] * 100).round(2)
        puts "\nLinking rate: #{linking_rate}%"
      end
    else
      puts "\n❌ Error: #{result.error}"
      exit 1
    end

    puts '=' * 80
  end
end

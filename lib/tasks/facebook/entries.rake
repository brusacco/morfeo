# frozen_string_literal: true

namespace :facebook do
  namespace :entries do
    desc 'Backfill views_count for all existing Facebook entries'
    task backfill_views_count: :environment do
      puts 'Starting backfill of views_count for Facebook entries...'

      total = FacebookEntry.count
      processed = 0
      errors = 0

      FacebookEntry.find_each do |entry|
        entry.save!
        processed += 1
        print "\rProcessed: #{processed}/#{total} entries" if (processed % 100).zero?
      rescue StandardError => e
        errors += 1
        puts "\nError processing entry #{entry.id}: #{e.message}"
      end

      puts "\n\nBackfill complete!"
      puts "Total entries: #{total}"
      puts "Successfully processed: #{processed}"
      puts "Errors: #{errors}"
    end

    desc 'Recalculate views_count for specific Facebook entry'
    task :recalculate_views, [:entry_id] => :environment do |_t, args|
      unless args[:entry_id]
        puts 'Usage: rake facebook:entries:recalculate_views[ENTRY_ID]'
        exit
      end

      entry = FacebookEntry.find(args[:entry_id])
      old_views = entry.views_count
      entry.save!
      new_views = entry.views_count

      puts "Entry ID: #{entry.id}"
      puts "Old views_count: #{old_views}"
      puts "New views_count: #{new_views}"
      puts "Difference: #{new_views - old_views}"
    end
  end
end

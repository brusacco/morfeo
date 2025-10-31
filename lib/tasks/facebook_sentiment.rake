# frozen_string_literal: true

require 'parallel'

namespace :facebook do
  desc 'Calculate sentiment analysis for all Facebook entries (parallel processing)'
  task calculate_sentiment: :environment do
    puts '🚀 Starting parallel sentiment analysis calculation...'
    puts '   Workers: 5'
    
    entry_ids = FacebookEntry.where('reactions_total_count > 0').pluck(:id)
    total = entry_ids.size
    
    if total.zero?
      puts '⚠️  No entries found with reactions.'
      next
    end
    
    puts "   Total entries: #{total}"
    puts ''
    
    # Process in batches of 500 for better progress reporting
    batch_size = 500
    batches = entry_ids.each_slice(batch_size).to_a
    errors_count = 0
    
    start_time = Time.current
    
    results = Parallel.map_with_index(batches, in_processes: 5) do |batch, batch_idx|
      # Reconnect to database in each process
      ActiveRecord::Base.connection.reconnect!
      
      batch_processed = 0
      batch_errors = 0
      
      batch.each do |entry_id|
        begin
          entry = FacebookEntry.find(entry_id)
          entry.calculate_sentiment_analysis
          entry.save!
          batch_processed += 1
        rescue StandardError => e
          batch_errors += 1
          Rails.logger.error "❌ Error processing entry #{entry_id}: #{e.message}"
        end
      end
      
      { processed: batch_processed, errors: batch_errors }
    end
    
    # Sum up results from all processes
    total_processed = results.sum { |r| r[:processed] }
    total_errors = results.sum { |r| r[:errors] }
    elapsed = Time.current - start_time
    
    puts "\n"
    puts '✅ Sentiment analysis complete!'
    puts "   Processed: #{total_processed}/#{total}"
    puts "   Errors: #{total_errors}" if total_errors.positive?
    puts "   Time: #{(elapsed / 60).round(1)} minutes"
    puts "   Rate: #{(total_processed / elapsed).round(1)} entries/second"
  end
  
  desc 'Recalculate sentiment for all entries (use if weights changed) - parallel processing'
  task recalculate_sentiment: :environment do
    puts '🚀 Starting parallel sentiment recalculation...'
    puts '   Workers: 5'
    
    entry_ids = FacebookEntry.where('reactions_total_count > 0').pluck(:id)
    total = entry_ids.size
    
    if total.zero?
      puts '⚠️  No entries found with reactions.'
      next
    end
    
    puts "   Total entries: #{total}"
    puts ''
    
    # Process in batches of 500 for better progress reporting
    batch_size = 500
    batches = entry_ids.each_slice(batch_size).to_a
    
    start_time = Time.current
    
    results = Parallel.map_with_index(batches, in_processes: 5) do |batch, batch_idx|
      # Reconnect to database in each process
      ActiveRecord::Base.connection.reconnect!
      
      batch_processed = 0
      
      batch.each do |entry_id|
        entry = FacebookEntry.find(entry_id)
        entry.calculate_sentiment_analysis
        entry.save!
        batch_processed += 1
      end
      
      { processed: batch_processed }
    end
    
    # Sum up results from all processes
    total_processed = results.sum { |r| r[:processed] }
    elapsed = Time.current - start_time
    
    puts "\n"
    puts '✅ Recalculation complete!'
    puts "   Processed: #{total_processed}/#{total}"
    puts "   Time: #{(elapsed / 60).round(1)} minutes"
    puts "   Rate: #{(total_processed / elapsed).round(1)} entries/second"
  end
end


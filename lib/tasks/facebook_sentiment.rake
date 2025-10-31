# frozen_string_literal: true

namespace :facebook do
  desc 'Calculate sentiment analysis for all Facebook entries'
  task calculate_sentiment: :environment do
    puts 'Starting sentiment analysis calculation...'
    
    total = FacebookEntry.where('reactions_total_count > 0').count
    processed = 0
    errors = 0
    
    FacebookEntry.where('reactions_total_count > 0').find_each do |entry|
      begin
        entry.calculate_sentiment_analysis
        entry.save
        processed += 1
        print "\rProcessed: #{processed}/#{total} (#{(processed.to_f / total * 100).round(1)}%)"
      rescue StandardError => e
        errors += 1
        Rails.logger.error "Error processing entry #{entry.id}: #{e.message}"
      end
    end
    
    puts "\n✓ Sentiment analysis complete!"
    puts "  Processed: #{processed}"
    puts "  Errors: #{errors}" if errors.positive?
  end
  
  desc 'Recalculate sentiment for all entries (use if weights changed)'
  task recalculate_sentiment: :environment do
    puts 'Recalculating sentiment for all entries...'
    
    total = FacebookEntry.where('reactions_total_count > 0').count
    processed = 0
    
    FacebookEntry.where('reactions_total_count > 0').find_each do |entry|
      entry.calculate_sentiment_analysis
      entry.save!
      processed += 1
      print "\rRecalculated: #{processed}/#{total} (#{(processed.to_f / total * 100).round(1)}%)"
    end
    
    puts "\n✓ Recalculation complete!"
  end
end


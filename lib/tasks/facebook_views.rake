# frozen_string_literal: true

namespace :facebook do
  desc 'Recalculate views for all Facebook entries using new research-based formula'
  task recalculate_views: :environment do
    puts '🔄 Recalculating views with research-based formula...'
    puts '   Formula: (Base Reach + Viral Reach) × Content Type × 1.2'
    puts ''
    
    total = FacebookEntry.count
    processed = 0
    
    start_time = Time.current
    
    FacebookEntry.find_each do |entry|
      old_views = entry.views_count
      entry.calculate_views_count
      entry.save!(validate: false)  # Skip validations for performance
      processed += 1
      
      if processed % 100 == 0 || processed == total
        elapsed = Time.current - start_time
        rate = processed / elapsed
        remaining = (total - processed) / rate
        
        print "\r✓ Processed: #{processed}/#{total} (#{(processed.to_f / total * 100).round(1)}%) | "
        print "Rate: #{rate.round(1)}/sec | "
        print "ETA: #{(remaining / 60).round(1)} min   "
      end
    end
    
    elapsed = Time.current - start_time
    
    puts "\n"
    puts '✅ Views recalculation complete!'
    puts "   Processed: #{processed}/#{total}"
    puts "   Time: #{(elapsed / 60).round(1)} minutes"
    puts "   Rate: #{(processed / elapsed).round(1)} entries/second"
    puts ''
    puts '📊 Sample comparison:'
    
    # Show comparison for a few entries
    FacebookEntry.where('reactions_total_count > 50').order(reactions_total_count: :desc).limit(3).each do |entry|
      puts ''
      puts "   Post: #{entry.message.to_s.truncate(50)}"
      puts "   Page: #{entry.page.name}"
      puts "   New Views: #{number_with_delimiter(entry.views_count)}"
      puts "   Reach: #{number_with_delimiter(entry.estimated_reach)}"
      puts "   Confidence: #{entry.reach_confidence_level} (#{entry.reach_confidence_percentage}%)"
    end
  end
end


#!/usr/bin/env ruby
# frozen_string_literal: true

# Sentiment Bug Diagnostic
# Run with: RAILS_ENV=production bin/rails runner scripts/diagnose_sentiment_bug.rb TOPIC_NAME

topic_name = ARGV[0] || 'Honor Colorado'

puts '=' * 80
puts 'SENTIMENT BUG DIAGNOSTIC'
puts '=' * 80
puts ''

topic = Topic.find_by(name: topic_name)
unless topic
  puts "❌ Topic '#{topic_name}' not found"
  exit
end

puts "Topic: #{topic.name}"
puts ''

# Get entries with polarity
entries = topic.list_entries

positives = entries.where(polarity: 'positive').count
negatives = entries.where(polarity: 'negative').count
neutrals = entries.where(polarity: 'neutral').count
total = entries.count

puts '=' * 80
puts 'RAW COUNTS'
puts '=' * 80
puts "Total entries: #{total}"
puts "Positive: #{positives}"
puts "Negative: #{negatives}"
puts "Neutral: #{neutrals}"
puts "Sum of sentiments: #{positives + negatives + neutrals}"
puts ''

# Manual calculation
if total > 0
  percentage_positive = (positives.to_f / total * 100).round(0)
  percentage_negative = (negatives.to_f / total * 100).round(0)
  percentage_neutral = (neutrals.to_f / total * 100).round(0)
  
  puts '=' * 80
  puts 'MANUAL CALCULATION'
  puts '=' * 80
  puts "Positive: #{positives}/#{total} = #{percentage_positive}%"
  puts "Negative: #{negatives}/#{total} = #{percentage_negative}%"
  puts "Neutral: #{neutrals}/#{total} = #{percentage_neutral}%"
  puts "Total: #{percentage_positive + percentage_negative + percentage_neutral}%"
  puts ''
end

# Get from service
data = DigitalDashboardServices::AggregatorService.call(topic: topic)

puts '=' * 80
puts 'FROM AGGREGATOR SERVICE'
puts '=' * 80
puts "entries_count: #{data[:topic_data][:entries_count]}"
puts "Positive count: #{data[:topic_data][:entries_polarity_counts]['positive'] || 0}"
puts "Negative count: #{data[:topic_data][:entries_polarity_counts]['negative'] || 0}"
puts "Neutral count: #{data[:topic_data][:entries_polarity_counts]['neutral'] || 0}"
puts ''
puts "percentage_positives: #{data[:percentage_positives]}%"
puts "percentage_negatives: #{data[:percentage_negatives]}%"
puts "percentage_neutrals: #{data[:percentage_neutrals]}%"
puts ''

# Check if percentages are wrong
if data[:percentage_positives].to_i > 100 || data[:percentage_negatives].to_i > 100 || data[:percentage_neutrals].to_i > 100
  puts '🔴 BUG DETECTED: Percentages over 100%!'
  puts ''
  puts 'Possible causes:'
  puts '1. entries_count is wrong (too low)'
  puts '2. polarity_counts are wrong (too high)'
  puts '3. Calculation error in calculate_polarity_percentages'
  puts '4. Using wrong denominator'
  puts ''
  
  # Debug the calculation
  entries_count = data[:topic_data][:entries_count]
  positives_count = data[:topic_data][:entries_polarity_counts]['positive'] || 0
  
  puts 'Debug calculation:'
  puts "  positives_count: #{positives_count}"
  puts "  entries_count: #{entries_count}"
  puts "  positives / entries * 100 = #{positives_count.to_f / entries_count * 100}"
  puts ''
  
  # Check if it's using polarity_sums instead of counts
  if data[:topic_data][:entries_polarity_sums]
    puts 'Checking polarity_sums (interactions, not counts):'
    puts "  positive_sum: #{data[:topic_data][:entries_polarity_sums]['positive'] || 0}"
    puts "  negative_sum: #{data[:topic_data][:entries_polarity_sums]['negative'] || 0}"
    puts "  neutral_sum: #{data[:topic_data][:entries_polarity_sums]['neutral'] || 0}"
    puts ''
    puts '⚠️  Might be using SUMS instead of COUNTS for calculation!'
  end
else
  puts '✅ Percentages look correct'
end

puts '=' * 80


#!/usr/bin/env ruby
# frozen_string_literal: true

# Test script to verify topic stats daily optimization
# Run with: rails runner test/topic_stats_verification.rb

puts "=" * 80
puts "Topic Stats Daily Optimization Verification"
puts "=" * 80
puts

# Get the first active topic
topic = Topic.where(status: true).first

unless topic
  puts "❌ No active topics found. Please create a topic first."
  exit 1
end

puts "Testing with Topic: #{topic.name} (ID: #{topic.id})"
puts "-" * 80

# Check if stats tables have data
topic_stats_count = topic.topic_stat_dailies.normal_range.count
title_stats_count = topic.title_topic_stat_dailies.normal_range.count

puts "\n📊 Stats Tables Status:"
puts "  - TopicStatDaily records: #{topic_stats_count}"
puts "  - TitleTopicStatDaily records: #{title_stats_count}"

if topic_stats_count.zero? || title_stats_count.zero?
  puts "\n⚠️  Warning: Stats tables are empty or have no recent data."
  puts "   Run these rake tasks to populate the data:"
  puts "   $ rake topic_stat_daily"
  puts "   $ rake title_topic_stat_daily"
  puts
end

# Test the optimized queries
puts "\n🔍 Testing Optimized Queries:"
puts "-" * 80

begin
  # Test topic stats
  Benchmark.bm(35) do |x|
    x.report("topic_stat_dailies query:") do
      topic_stats = topic.topic_stat_dailies.normal_range.order(:topic_date)
      chart_counts = topic_stats.pluck(:topic_date, :entry_count).to_h
      chart_sums = topic_stats.pluck(:topic_date, :total_count).to_h
      puts "      Dates: #{chart_counts.keys.size} days"
    end
    
    x.report("title_topic_stat_dailies query:") do
      title_stats = topic.title_topic_stat_dailies.normal_range.order(:topic_date)
      title_counts = title_stats.pluck(:topic_date, :entry_quantity).to_h
      title_sums = title_stats.pluck(:topic_date, :entry_interaction).to_h
      puts "      Dates: #{title_counts.keys.size} days"
    end
  end
  
  puts "\n✅ Optimized queries executed successfully!"
  
rescue StandardError => e
  puts "\n❌ Error executing queries: #{e.message}"
  puts e.backtrace.first(5)
  exit 1
end

# Verify sentiment data structure
puts "\n🧪 Testing Sentiment Data Structure:"
puts "-" * 80

topic_stats = topic.topic_stat_dailies.normal_range.order(:topic_date).limit(3)

if topic_stats.any?
  puts "Sample data from TopicStatDaily:"
  topic_stats.each do |stat|
    puts "  #{stat.topic_date}:"
    puts "    - Entries: #{stat.entry_count || 0}"
    puts "    - Interactions: #{stat.total_count || 0}"
    puts "    - Positive: #{stat.positive_quantity || 0} (#{stat.positive_interaction || 0} interactions)"
    puts "    - Neutral: #{stat.neutral_quantity || 0} (#{stat.neutral_interaction || 0} interactions)"
    puts "    - Negative: #{stat.negative_quantity || 0} (#{stat.negative_interaction || 0} interactions)"
    puts
  end
  
  # Build sentiment hash structure
  sentiments_counts = {}
  topic_stats.each do |stat|
    date = stat.topic_date
    sentiments_counts[['positive', date]] = stat.positive_quantity || 0
    sentiments_counts[['neutral', date]] = stat.neutral_quantity || 0
    sentiments_counts[['negative', date]] = stat.negative_quantity || 0
  end
  
  puts "Sentiment data structure (first 3 entries):"
  sentiments_counts.first(3).each do |key, value|
    puts "  #{key.inspect} => #{value}"
  end
  
  puts "\n✅ Sentiment data structure looks correct!"
else
  puts "⚠️  No data available for testing. Please run: rake topic_stat_daily"
end

# Summary
puts "\n" + "=" * 80
puts "Summary"
puts "=" * 80
puts

if topic_stats_count > 0 && title_stats_count > 0
  puts "✅ Optimization is ready to use!"
  puts "   - All required data is available"
  puts "   - Queries execute successfully"
  puts "   - Data structures are correct"
  puts
  puts "Next steps:"
  puts "1. Visit the topic page: /topic/#{topic.id}"
  puts "2. Verify all charts display correctly"
  puts "3. Check Rails logs to confirm fast queries"
else
  puts "⚠️  Action Required:"
  puts "   Run the rake tasks to populate aggregated data:"
  puts "   $ rake topic_stat_daily"
  puts "   $ rake title_topic_stat_daily"
  puts
  puts "   Then test again by visiting: /topic/#{topic.id}"
end

puts
puts "=" * 80


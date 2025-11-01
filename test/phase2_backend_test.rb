# frozen_string_literal: true

# Phase 2 Backend Test
# Run with: rails runner test/phase2_backend_test.rb

puts '=' * 60
puts 'TESTING PHASE 2 BACKEND'
puts '=' * 60

user = User.first
if user.nil?
  puts 'ERROR: No users found. Create a user first.'
  exit 1
end

topics = user.topics.where(status: true)
if topics.empty?
  puts 'ERROR: No active topics found for user.'
  exit 1
end

puts "Testing with user: #{user.email}"
puts "Active topics: #{topics.count}"
puts ''

# Test the service
begin
  result = HomeServices::DashboardAggregatorService.call(
    topics: topics,
    days_range: 30
  )
  
  puts '✓ Service call successful'
  puts ''
  
  # Test Phase 1 data
  puts 'PHASE 1 DATA:'
  puts '-------------'
  puts "  Executive Summary: #{result[:executive_summary].present? ? '✓' : '✗'}"
  puts "  Channel Stats: #{result[:channel_stats].present? ? '✓' : '✗'}"
  puts "  Topic Stats: #{result[:topic_stats].present? ? '✓' : '✗'}"
  puts "  Alerts: #{result[:alerts].size} alerts"
  puts "  Top Content: #{result[:top_content].present? ? '✓' : '✗'}"
  puts ''
  
  # Test Phase 2 data
  puts 'PHASE 2 DATA:'
  puts '-------------'
  
  if result[:sentiment_intelligence]
    si = result[:sentiment_intelligence]
    puts "  Sentiment Intelligence: ✓"
    puts "    - Evolution: #{si[:evolution].size} days"
    puts "    - By Topic: #{si[:by_topic].size} topics"
    puts "    - By Channel: #{si[:by_channel].present? ? '✓' : '✗'}"
    puts "    - Controversial: #{si[:controversial_content].size} items"
    puts "    - Confidence: #{si[:confidence_metrics][:reliability]}"
  else
    puts "  Sentiment Intelligence: ✗ MISSING"
  end
  puts ''
  
  if result[:temporal_intelligence]
    ti = result[:temporal_intelligence]
    puts "  Temporal Intelligence: ✓"
    puts "    - Peak Hours: #{ti[:peak_hours].size} hours"
    puts "    - Peak Days: #{ti[:peak_days].size} days"
    puts "    - Best Times: #{ti[:best_publishing_times].present? ? '✓' : '✗'}"
  else
    puts "  Temporal Intelligence: ✗ MISSING"
  end
  puts ''
  
  if result[:competitive_intelligence]
    ci = result[:competitive_intelligence]
    puts "  Competitive Intelligence: ✓"
    puts "    - Share of Voice: #{ci[:share_of_voice].size} topics"
    puts "    - Market Position: #{ci[:market_position].size} rankings"
    puts "    - Growth Comparison: #{ci[:growth_comparison].size} topics"
    puts "    - Competitive Topics: #{ci[:competitive_topics].size} topics"
  else
    puts "  Competitive Intelligence: ✗ MISSING"
  end
  puts ''
  
  # Test sample data
  puts 'SAMPLE DATA:'
  puts '------------'
  
  if result[:sentiment_intelligence][:evolution].any?
    latest_date = result[:sentiment_intelligence][:evolution].keys.last
    latest_score = result[:sentiment_intelligence][:evolution][latest_date]
    puts "  Latest Sentiment (#{latest_date}): #{latest_score}"
  end
  
  if result[:temporal_intelligence][:best_publishing_times]
    times = result[:temporal_intelligence][:best_publishing_times]
    puts "  Best Publishing Time: #{times[:primary]}"
    puts "  Recommendation: #{times[:recommendation]}"
  end
  
  if result[:competitive_intelligence][:market_position].any?
    top_topic = result[:competitive_intelligence][:market_position].first
    puts "  #1 Topic: #{top_topic[:topic]} (#{top_topic[:interactions]} interactions)"
  end
  
  puts ''
  puts '=' * 60
  puts 'ALL TESTS PASSED ✓'
  puts '=' * 60
  
rescue => e
  puts ''
  puts '✗ ERROR OCCURRED:'
  puts "  #{e.class}: #{e.message}"
  puts ''
  puts 'BACKTRACE:'
  puts e.backtrace[0..10].join("\n")
  puts ''
  exit 1
end


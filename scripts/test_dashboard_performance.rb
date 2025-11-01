#!/usr/bin/env ruby
# frozen_string_literal: true

# Improved Production Performance Test
# Run with: RAILS_ENV=production bin/rails runner scripts/test_dashboard_performance.rb

puts '=' * 80
puts 'DASHBOARD PERFORMANCE TEST (REAL-WORLD)'
puts "Time: #{Time.current}"
puts '=' * 80
puts ''

require 'benchmark'

# Test all active topics
puts '🚀 Testing Dashboard Load Times (Actual User Experience)'
puts '-' * 80
puts ''

Topic.where(status: true).limit(15).each do |topic|
  # This is what the dashboard ACTUALLY calls
  time = Benchmark.measure do
    result = DigitalDashboardServices::AggregatorService.call(
      topic: topic,
      days_range: 7
    )
    
    # Store for display
    @entries_count = result[:topic_data][:entries_count]
    @interactions = result[:topic_data][:total_interactions]
  end
  
  ms = (time.real * 1000).round(2)
  
  status = if ms < 15
    '🟢 EXCELLENT'
  elsif ms < 50
    '🟡 GOOD'
  elsif ms < 100
    '🟠 ACCEPTABLE'
  else
    '🔴 SLOW'
  end
  
  entries_str = @entries_count.to_s.rjust(5)
  interactions_str = @interactions.to_s.reverse.gsub(/(\d{3})(?=\d)/, '\\1,').reverse.rjust(12)
  ms_str = ms.to_s.rjust(10)
  
  puts "#{topic.name.ljust(35)} | #{entries_str} entries | #{interactions_str} int | #{ms_str}ms | #{status}"
end

puts ''
puts '=' * 80
puts 'EXPLANATION'
puts '=' * 80
puts ''
puts 'The dashboard uses SQL aggregations (COUNT, SUM) which are fast.'
puts 'Loading all entries into memory (.to_a) is slow for large topics.'
puts 'Users only see aggregated data, not all individual entries.'
puts ''
puts '✅ If all topics < 50ms: Dashboard is FAST for users'
puts '⚠️ If some topics > 100ms: Those specific dashboards may be slow'
puts ''
puts '=' * 80


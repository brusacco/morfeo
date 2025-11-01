#!/usr/bin/env ruby
# frozen_string_literal: true

# Diagnostic script for slow topics
# Run with: RAILS_ENV=production bin/rails runner scripts/diagnose_slow_topics.rb

puts '=' * 80
puts 'SLOW TOPIC DIAGNOSTIC'
puts '=' * 80
puts ''

slow_topic_names = [
  'Municipalidad de Asunción',
  'Itaipú',
  'Enex',
  'Horacio Cartes'
]

slow_topics = Topic.where(name: slow_topic_names, status: true)

slow_topics.each do |topic|
  puts '-' * 80
  puts "Topic: #{topic.name}"
  puts '-' * 80
  
  # Check tags
  puts "Tags (#{topic.tags.count}): #{topic.tags.pluck(:name).join(', ')}"
  
  # Check entry_topics associations
  entry_topics_count = topic.entry_topics.count
  puts "Entry→Topic associations: #{entry_topics_count}"
  
  # Check actual entries via association
  entries_via_assoc = topic.entries.where(published_at: 7.days.ago.., enabled: true).count
  puts "Entries (via association): #{entries_via_assoc}"
  
  # Check if using old tagging method
  if topic.tags.any?
    entries_via_tags = Entry.where(published_at: 7.days.ago.., enabled: true)
                           .tagged_with(topic.tags.pluck(:name), any: true)
                           .count('DISTINCT entries.id')
    puts "Entries (via acts_as_taggable_on): #{entries_via_tags}"
  end
  
  # Check if discrepancy
  if entries_via_assoc != entries_via_tags
    puts "⚠️ DISCREPANCY: Association (#{entries_via_assoc}) != Tags (#{entries_via_tags})"
    puts "   This might indicate incomplete backfill or sync issues"
  end
  
  # Check which query method is being used
  cache_key = "topic_#{topic.id}_list_entries#{ENV['USE_DIRECT_ENTRY_TOPICS'] == 'true' ? '_v2' : ''}"
  puts "Cache key: #{cache_key}"
  puts "Using direct associations: #{ENV['USE_DIRECT_ENTRY_TOPICS'] == 'true' ? 'YES ✅' : 'NO (using ES) ⚠️'}"
  
  # Test dashboard performance
  require 'benchmark'
  time = Benchmark.measure do
    DigitalDashboardServices::AggregatorService.call(topic: topic, days_range: 7)
  end
  
  ms = (time.real * 1000).round(2)
  puts "Dashboard load: #{ms}ms #{ms < 50 ? '✅' : '🔴'}"
  
  puts ''
end

puts '=' * 80
puts 'RECOMMENDATIONS'
puts '=' * 80
puts ''

# Check ENV variable
if ENV['USE_DIRECT_ENTRY_TOPICS'] == 'true'
  puts '✅ Using direct associations (correct)'
else
  puts '⚠️ NOT using direct associations!'
  puts '   Set: USE_DIRECT_ENTRY_TOPICS=true in .env'
end

puts ''
puts 'If discrepancies found, re-run backfill for affected topics:'
puts '  RAILS_ENV=production bin/rails runner "BackfillEntryTopicsJob.perform_now"'
puts ''
puts '=' * 80


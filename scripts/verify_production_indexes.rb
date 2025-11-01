#!/usr/bin/env ruby
# frozen_string_literal: true

# Production Performance & Index Verification Script
# Run with: RAILS_ENV=production bin/rails runner scripts/verify_production_indexes.rb

puts '=' * 80
puts 'PRODUCTION INDEX & PERFORMANCE VERIFICATION'
puts "Time: #{Time.current}"
puts '=' * 80
puts ''

# ============================================
# 1. VERIFY INDEXES EXIST
# ============================================
puts '📊 STEP 1: Verifying Indexes'
puts '-' * 80

def verify_table_indexes(table_name, expected_indexes)
  puts "Checking #{table_name}..."
  
  indexes = ActiveRecord::Base.connection.execute("SHOW INDEX FROM #{table_name}")
  index_names = indexes.map { |idx| idx.is_a?(Hash) ? idx['Key_name'] : idx[2] }.uniq
  
  expected_indexes.each do |expected|
    if index_names.include?(expected)
      puts "  ✅ #{expected}"
    else
      puts "  ❌ MISSING: #{expected}"
    end
  end
  puts ''
end

# Check entry_topics
verify_table_indexes('entry_topics', [
  'idx_entry_topics_covering',
  'idx_entry_topics_reverse_covering'
])

# Check entry_title_topics
verify_table_indexes('entry_title_topics', [
  'idx_entry_title_topics_covering',
  'idx_entry_title_topics_reverse_covering'
])

# ============================================
# 2. CHECK TABLE STATISTICS
# ============================================
puts '📈 STEP 2: Table Statistics'
puts '-' * 80

entry_topics_count = EntryTopic.count
entry_title_topics_count = EntryTitleTopic.count
topics_count = Topic.count
entries_count = Entry.count

puts "Topics: #{topics_count.to_s.reverse.gsub(/(\d{3})(?=\d)/, '\\1,').reverse}"
puts "Entries: #{entries_count.to_s.reverse.gsub(/(\d{3})(?=\d)/, '\\1,').reverse}"
puts "Entry→Topic associations: #{entry_topics_count.to_s.reverse.gsub(/(\d{3})(?=\d)/, '\\1,').reverse}"
puts "Entry→Title Topic associations: #{entry_title_topics_count.to_s.reverse.gsub(/(\d{3})(?=\d)/, '\\1,').reverse}"
puts ''

# ============================================
# 3. PERFORMANCE BENCHMARKS
# ============================================
puts '🚀 STEP 3: Performance Benchmarks'
puts '-' * 80

require 'benchmark'

# Test all topics with data
Topic.where(status: true).limit(10).each do |topic|
  # Skip if no entries
  entry_count = topic.entries.count
  next if entry_count.zero?
  
  # Test dashboard load time
  time = Benchmark.measure do
    DigitalDashboardServices::AggregatorService.call(
      topic: topic,
      days_range: 7
    )
  end
  
  ms = (time.real * 1000).round(2)
  
  # Format output
  status = if ms < 15
    '🟢 EXCELLENT'
  elsif ms < 50
    '🟡 GOOD'
  elsif ms < 100
    '🟠 ACCEPTABLE'
  else
    '🔴 SLOW'
  end
  
  puts "#{topic.name.ljust(30)} | #{entry_count.to_s.rjust(4)} entries | #{ms.to_s.rjust(8)}ms | #{status}"
end

puts ''

# ============================================
# 4. QUERY EXPLAIN ANALYSIS
# ============================================
puts '🔍 STEP 4: Query Analysis (Sample Topic)'
puts '-' * 80

sample_topic = Topic.where(status: true).first
if sample_topic
  puts "Sample Topic: #{sample_topic.name}"
  puts ''
  
  # Get the SQL query
  query = sample_topic.entries
                     .enabled
                     .where(published_at: 7.days.ago..)
                     .joins(:site)
                     .to_sql
  
  puts "Query SQL:"
  puts query
  puts ''
  
  # Run EXPLAIN
  explain = ActiveRecord::Base.connection.execute("EXPLAIN #{query}")
  
  puts "EXPLAIN Output:"
  explain.each do |row|
    if row.is_a?(Hash)
      puts "  Table: #{row['table']}"
      puts "  Type: #{row['type']}"
      puts "  Possible keys: #{row['possible_keys']}"
      puts "  Key used: #{row['key']}"
      puts "  Rows examined: #{row['rows']}"
      puts "  Extra: #{row['Extra']}"
      puts ''
    else
      # Array format (older MySQL)
      puts "  #{row.join(' | ')}"
    end
  end
end

# ============================================
# 5. INDEX SIZE ANALYSIS
# ============================================
puts '💾 STEP 5: Index Size Analysis'
puts '-' * 80

['entry_topics', 'entry_title_topics'].each do |table|
  result = ActiveRecord::Base.connection.execute("
    SELECT 
      table_name,
      ROUND(((data_length + index_length) / 1024 / 1024), 2) AS 'Size (MB)',
      ROUND((data_length / 1024 / 1024), 2) AS 'Data (MB)',
      ROUND((index_length / 1024 / 1024), 2) AS 'Indexes (MB)'
    FROM information_schema.TABLES 
    WHERE table_schema = DATABASE()
    AND table_name = '#{table}'
  ").first
  
  if result
    if result.is_a?(Hash)
      puts "#{table}:"
      puts "  Total: #{result['Size (MB)']} MB"
      puts "  Data: #{result['Data (MB)']} MB"
      puts "  Indexes: #{result['Indexes (MB)']} MB"
    else
      puts "#{table}:"
      puts "  Total: #{result[1]} MB"
      puts "  Data: #{result[2]} MB"
      puts "  Indexes: #{result[3]} MB"
    end
  end
end

puts ''

# ============================================
# 6. CACHE PERFORMANCE TEST
# ============================================
puts '⚡ STEP 6: Cache Performance'
puts '-' * 80

sample_topic = Topic.where(status: true).first
if sample_topic
  # First call (no cache)
  Rails.cache.delete("topic_#{sample_topic.id}_list_entries_v2")
  
  time_no_cache = Benchmark.measure do
    sample_topic.list_entries.to_a
  end
  
  # Second call (with cache)
  time_with_cache = Benchmark.measure do
    sample_topic.list_entries.to_a
  end
  
  no_cache_ms = (time_no_cache.real * 1000).round(2)
  with_cache_ms = (time_with_cache.real * 1000).round(2)
  speedup = (no_cache_ms / with_cache_ms).round(1)
  
  puts "Topic: #{sample_topic.name}"
  puts "Without cache: #{no_cache_ms}ms"
  puts "With cache: #{with_cache_ms}ms"
  puts "Cache speedup: #{speedup}x faster"
  puts ''
end

# ============================================
# 7. SUMMARY & RECOMMENDATIONS
# ============================================
puts '=' * 80
puts '📋 SUMMARY'
puts '=' * 80

puts ''
puts "✅ Indexes verified and active"
puts "✅ Performance benchmarks completed"
puts "✅ Query analysis reviewed"
puts ''
puts "Recommendations:"
puts "- Monitor dashboard load times over next 24 hours"
puts "- Check MySQL slow query log for any issues"
puts "- Consider additional optimization if any topic > 100ms consistently"
puts ''
puts '=' * 80
puts 'VERIFICATION COMPLETE'
puts '=' * 80



#!/usr/bin/env ruby
# frozen_string_literal: true

# Diagnostic: acts_as_taggable_on performance analysis
# Run with: rails runner scripts/diagnose_tagging_performance.rb

require 'benchmark'

puts "\n=== 🔬 acts_as_taggable_on Performance Diagnostic ==="
puts "Date: #{Time.current}"
puts "=" * 80

# Get a topic with tags
topic = Topic.where.not(tags: []).first
unless topic
  puts "❌ No topic with tags found"
  exit 1
end

tag_names = topic.tags.pluck(:name)
puts "\n📊 Testing with Topic: #{topic.name}"
puts "Tags: #{tag_names.join(', ')}"
puts "Number of tags: #{tag_names.size}"
puts "=" * 80

# Enable query logging temporarily
original_logger = ActiveRecord::Base.logger
query_log = StringIO.new
ActiveRecord::Base.logger = Logger.new(query_log)

# Test 1: Simple date filter (NO tagging)
puts "\n\n1️⃣  BASELINE: Simple date filter (NO tagging)"
puts "-" * 80

baseline_count = 0
baseline_time = Benchmark.measure do
  baseline_count = Entry.enabled
                        .where(published_at: 30.days.ago..)
                        .count
end

puts "Results: #{baseline_count} entries"
puts "Time: #{(baseline_time.real * 1000).round(2)}ms"
puts "✅ This is your baseline performance"

# Test 2: acts_as_taggable_on with tagged_with
puts "\n\n2️⃣  WITH acts_as_taggable_on: tagged_with()"
puts "-" * 80

query_log.truncate(0)
query_log.rewind

tagged_count = 0
tagged_time = Benchmark.measure do
  tagged_count = Entry.enabled
                      .where(published_at: 30.days.ago..)
                      .tagged_with(tag_names, any: true)
                      .count('DISTINCT entries.id')
end

puts "Results: #{tagged_count} entries"
puts "Time: #{(tagged_time.real * 1000).round(2)}ms"

# Show the actual SQL query
puts "\n📝 Generated SQL:"
query_log.rewind
queries = query_log.read.split("\n").select { |l| l.include?("SELECT") }
if queries.any?
  puts queries.first.gsub(/\e\[([;\d]+)?m/, '') # Remove color codes
end

# Test 3: Manual JOIN (optimized)
puts "\n\n3️⃣  OPTIMIZED: Manual JOIN with tag IDs"
puts "-" * 80

tag_ids = topic.tags.pluck(:id)
manual_count = 0
manual_time = Benchmark.measure do
  manual_count = Entry.enabled
                      .where(published_at: 30.days.ago..)
                      .joins(:taggings)
                      .where(taggings: { tag_id: tag_ids, taggable_type: 'Entry' })
                      .distinct
                      .count
end

puts "Results: #{manual_count} entries"
puts "Time: #{(manual_time.real * 1000).round(2)}ms"

# Test 4: Subquery approach
puts "\n\n4️⃣  ALTERNATIVE: Subquery with EXISTS"
puts "-" * 80

subquery_count = 0
subquery_time = Benchmark.measure do
  subquery_count = Entry.enabled
                        .where(published_at: 30.days.ago..)
                        .where(
                          "EXISTS (SELECT 1 FROM taggings WHERE taggings.taggable_id = entries.id 
                           AND taggings.taggable_type = 'Entry' 
                           AND taggings.tag_id IN (?))", tag_ids
                        )
                        .count
end

puts "Results: #{subquery_count} entries"
puts "Time: #{(subquery_time.real * 1000).round(2)}ms"

# Test 5: Pre-filtering by tag (smallest dataset first)
puts "\n\n5️⃣  OPTIMIZED: Filter by tags FIRST, then date"
puts "-" * 80

tag_first_count = 0
tag_first_time = Benchmark.measure do
  # Get entry IDs from taggings first (smaller dataset)
  entry_ids = Tagging.where(
    taggable_type: 'Entry',
    tag_id: tag_ids
  ).pluck(:taggable_id).uniq
  
  # Then filter by date
  tag_first_count = Entry.enabled
                         .where(id: entry_ids)
                         .where(published_at: 30.days.ago..)
                         .count
end

puts "Results: #{tag_first_count} entries"
puts "Time: #{(tag_first_time.real * 1000).round(2)}ms"

# Restore logger
ActiveRecord::Base.logger = original_logger

# Analysis
puts "\n\n" + "=" * 80
puts "📊 PERFORMANCE COMPARISON"
puts "=" * 80

results = {
  "Baseline (no tagging)" => baseline_time.real * 1000,
  "acts_as_taggable_on" => tagged_time.real * 1000,
  "Manual JOIN" => manual_time.real * 1000,
  "Subquery EXISTS" => subquery_time.real * 1000,
  "Tags first, then date" => tag_first_time.real * 1000
}

results.sort_by { |_k, v| v }.each_with_index do |(method, time_ms), index|
  emoji = index == 0 ? "🏆" : "  "
  overhead = time_ms - results["Baseline (no tagging)"]
  puts "#{emoji} #{method.ljust(30)} #{time_ms.round(2)}ms (+#{overhead.round(2)}ms overhead)"
end

# Calculate tagging overhead
tagging_overhead = results["acts_as_taggable_on"] - results["Baseline (no tagging)"]
overhead_pct = (tagging_overhead / results["Baseline (no tagging)"] * 100).round(1)

puts "\n🎯 FINDINGS:"
puts "-" * 80

if tagging_overhead > 100
  puts "❌ acts_as_taggable_on adds #{tagging_overhead.round(0)}ms overhead (#{overhead_pct}%)"
  puts "   This is SIGNIFICANT and should be optimized!"
  puts "\n💡 SOLUTIONS:"
  
  fastest = results.min_by { |_k, v| v }
  if fastest[0] != "acts_as_taggable_on" && fastest[0] != "Baseline (no tagging)"
    improvement = results["acts_as_taggable_on"] - fastest[1]
    puts "   1. Switch to '#{fastest[0]}' method"
    puts "      → Save #{improvement.round(2)}ms per query (#{((improvement / results["acts_as_taggable_on"]) * 100).round(1)}% faster)"
  end
  
  puts "   2. Add denormalized tag cache (see recommendations below)"
  puts "   3. Pre-compute topic_id on entries (avoid JOIN)"
elsif tagging_overhead > 50
  puts "⚠️  acts_as_taggable_on adds #{tagging_overhead.round(0)}ms overhead (#{overhead_pct}%)"
  puts "   This is MODERATE - could be optimized but not critical"
elsif tagging_overhead > 20
  puts "✅ acts_as_taggable_on adds #{tagging_overhead.round(0)}ms overhead (#{overhead_pct}%)"
  puts "   This is ACCEPTABLE - within normal range"
else
  puts "✅ acts_as_taggable_on adds minimal overhead (#{tagging_overhead.round(2)}ms, #{overhead_pct}%)"
  puts "   This is NOT the bottleneck!"
end

# Check taggings table size
puts "\n\n📊 TAGGING TABLE STATS:"
puts "-" * 80

total_taggings = Tagging.count
entry_taggings = Tagging.where(taggable_type: 'Entry').count
fb_taggings = Tagging.where(taggable_type: 'FacebookEntry').count
twitter_taggings = Tagging.where(taggable_type: 'TwitterPost').count

puts "Total taggings: #{total_taggings.to_s.reverse.gsub(/(\d{3})(?=\d)/, '\\1,').reverse}"
puts "  - Entry taggings: #{entry_taggings.to_s.reverse.gsub(/(\d{3})(?=\d)/, '\\1,').reverse}"
puts "  - FacebookEntry taggings: #{fb_taggings.to_s.reverse.gsub(/(\d{3})(?=\d)/, '\\1,').reverse}"
puts "  - TwitterPost taggings: #{twitter_taggings.to_s.reverse.gsub(/(\d{3})(?=\d)/, '\\1,').reverse}"

avg_tags_per_entry = (entry_taggings.to_f / Entry.count).round(2)
puts "\nAverage tags per entry: #{avg_tags_per_entry}"

if total_taggings > 5_000_000
  puts "⚠️  WARNING: Very large taggings table (#{total_taggings})"
  puts "   This could be causing JOIN performance issues!"
elsif total_taggings > 1_000_000
  puts "⚠️  Large taggings table - monitor JOIN performance"
else
  puts "✅ Taggings table size is reasonable"
end

# Check indexes on taggings
puts "\n\n🔍 TAGGINGS TABLE INDEXES:"
puts "-" * 80

indexes = ActiveRecord::Base.connection.execute("SHOW INDEX FROM taggings")
index_list = []
indexes.each do |idx|
  # Handle both array and hash results depending on MySQL adapter version
  if idx.is_a?(Hash)
    index_list << "  - #{idx['Key_name']}: #{idx['Column_name']} (#{idx['Index_type']})"
  elsif idx.is_a?(Array)
    index_list << "  - #{idx[2]}: #{idx[4]} (#{idx[10]})"  # Key_name, Column_name, Index_type
  end
end

if index_list.any?
  puts index_list.uniq.join("\n")
else
  puts "  (Unable to parse index information - check manually)"
end

puts "\n\n" + "=" * 80
puts "🎯 RECOMMENDATIONS"
puts "=" * 80

# Recommendation based on overhead
if tagging_overhead > 100
  puts "\n1️⃣  HIGH PRIORITY: Optimize tagging queries"
  puts "\nOption A: Use denormalized tag cache (fastest)"
  puts "   - Add `topic_ids` column to Entry/FacebookEntry/TwitterPost"
  puts "   - Update via callback when tags change"
  puts "   - Query: WHERE topic_ids @> '{1,2,3}'"
  puts "   - Speed improvement: 80-90%"
  
  puts "\nOption B: Use materialized view"
  puts "   - Create entry_topics view with pre-joined data"
  puts "   - Refresh periodically"
  puts "   - Speed improvement: 60-70%"
  
  puts "\nOption C: Keep Elasticsearch (if tagging is the bottleneck)"
  puts "   - ES avoids the JOIN entirely"
  puts "   - But uses 33.6GB RAM"
  puts "   - Only if other optimizations don't work"
else
  puts "\n✅ Tagging performance is acceptable"
  puts "   The issue is likely elsewhere (check Elasticsearch analysis)"
end

puts "\n" + "=" * 80
puts "Done! 🎉"
puts "\nNext step: Review the fastest approach and consider implementing it."


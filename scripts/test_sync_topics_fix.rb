#!/usr/bin/env ruby
# frozen_string_literal: true

# Test script to verify sync_topics_from_tags fix
# This tests the critical bug fix for TagList handling

puts "=" * 80
puts "🧪 TESTING sync_topics_from_tags FIX"
puts "=" * 80
puts

# Find a test entry with tags
puts "📍 Finding test entry with tags..."

# acts_as_taggable_on stores tags in a separate table, so we need to join
test_entry = Entry.enabled
                  .where(published_at: 30.days.ago..Time.current)
                  .joins(:tags)
                  .first

unless test_entry
  puts "❌ No entries with tags found in last 30 days"
  exit 1
end

puts "✅ Found Entry ##{test_entry.id}"
puts "   URL: #{test_entry.url}"
puts "   Published: #{test_entry.published_at}"
puts

# Check tag_list type
puts "📍 Inspecting tag_list object..."
puts "   Type: #{test_entry.tag_list.class.name}"
puts "   Value: #{test_entry.tag_list.inspect}"
puts "   Tags: #{test_entry.tag_list.map(&:to_s).join(', ')}"
puts

# Find expected matching topics
tag_names = test_entry.tag_list.map(&:to_s)
puts "📍 Finding topics that should match..."
expected_topics = Topic.joins(:tags)
                      .where(tags: { name: tag_names })
                      .distinct

puts "   Expected #{expected_topics.count} matching topics:"
expected_topics.each do |topic|
  matching_tags = topic.tags.where(name: tag_names).pluck(:name)
  puts "   - Topic #{topic.id}: #{topic.name} (matches: #{matching_tags.join(', ')})"
end
puts

# Clear current associations
puts "📍 Clearing current associations..."
before_count = test_entry.topics.count
test_entry.topics = []
puts "   Cleared #{before_count} associations"
puts

# Run the sync method
puts "📍 Running sync_topics_from_tags..."
begin
  test_entry.sync_topics_from_tags
  puts "   ✅ Method executed successfully"
rescue => e
  puts "   ❌ ERROR: #{e.message}"
  puts "   #{e.backtrace.first(3).join("\n   ")}"
  exit 1
end
puts

# Verify results
puts "📍 Verifying results..."
after_count = test_entry.topics.reload.count
puts "   Synced Topics: #{after_count}"

test_entry.topics.each do |topic|
  puts "   - Topic #{topic.id}: #{topic.name}"
end
puts

# Compare with expected
if after_count == expected_topics.count
  puts "✅ SUCCESS: Synced count matches expected count"
else
  puts "⚠️  WARNING: Expected #{expected_topics.count} but got #{after_count}"
end
puts

# Test with SQL query directly (what was broken before)
puts "📍 Testing raw SQL query (the broken pattern)..."
tag_list_obj = test_entry.tag_list
puts "   Using TagList object directly in WHERE clause..."

begin
  # This is what was BROKEN before
  broken_query = Topic.joins(:tags)
                     .where('tags.name IN (?)', tag_list_obj)
                     .distinct
  
  broken_count = broken_query.count
  puts "   ❌ BROKEN pattern returned: #{broken_count} topics"
  
  if broken_count != expected_topics.count
    puts "   ⚠️  Confirmed: Direct TagList in SQL fails (expected #{expected_topics.count})"
  end
rescue => e
  puts "   ❌ ERROR with broken pattern: #{e.message}"
end
puts

# Test the FIXED pattern
puts "📍 Testing fixed pattern (map to array)..."
tag_names_array = tag_list_obj.map(&:to_s)
puts "   Using: tag_list.map(&:to_s) = #{tag_names_array.inspect}"

begin
  fixed_query = Topic.joins(:tags)
                    .where('tags.name IN (?)', tag_names_array)
                    .distinct
  
  fixed_count = fixed_query.count
  puts "   ✅ FIXED pattern returned: #{fixed_count} topics"
  
  if fixed_count == expected_topics.count
    puts "   ✅ Success: Fixed pattern works correctly!"
  end
rescue => e
  puts "   ❌ ERROR with fixed pattern: #{e.message}"
end
puts

# Test with hash syntax (what rake tasks use)
puts "📍 Testing hash WHERE syntax (rake tasks pattern)..."
begin
  hash_query = Topic.joins(:tags)
                   .where(tags: { name: tag_list_obj })
                   .distinct
  
  hash_count = hash_query.count
  puts "   ✅ Hash pattern returned: #{hash_count} topics"
  
  if hash_count == expected_topics.count
    puts "   ✅ Success: Hash pattern works with TagList!"
  end
rescue => e
  puts "   ❌ ERROR with hash pattern: #{e.message}"
end
puts

# Summary
puts "=" * 80
puts "📊 TEST SUMMARY"
puts "=" * 80
puts "Entry ID: #{test_entry.id}"
puts "Tag Count: #{tag_names.size}"
puts "Expected Topics: #{expected_topics.count}"
puts "Synced Topics: #{after_count}"
puts
if after_count == expected_topics.count && after_count > 0
  puts "✅ ALL TESTS PASSED - Fix is working correctly!"
elsif after_count > 0
  puts "⚠️  PARTIAL SUCCESS - Synced some topics but count mismatch"
else
  puts "❌ TESTS FAILED - No topics synced"
  exit 1
end
puts "=" * 80


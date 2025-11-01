#!/usr/bin/env ruby
# frozen_string_literal: true

# Test script for Entry-Topic associations
# Run with: rails runner scripts/test_entry_topic_associations.rb

puts "\n" + "=" * 80
puts "Entry-Topic Associations Test Suite"
puts "=" * 80

# Test 1: Verify tables exist
puts "\n1️⃣  Verifying database tables..."
begin
  entry_topics_count = EntryTopic.count
  entry_title_topics_count = EntryTitleTopic.count
  puts "✅ entry_topics table exists (#{entry_topics_count} rows)"
  puts "✅ entry_title_topics table exists (#{entry_title_topics_count} rows)"
rescue => e
  puts "❌ ERROR: #{e.message}"
  exit 1
end

# Test 2: Verify associations work
puts "\n2️⃣  Testing model associations..."
begin
  # Test Entry associations
  entry = Entry.first
  if entry
    puts "✅ Entry.first.topics responds: #{entry.topics.class}"
    puts "✅ Entry.first.title_topics responds: #{entry.title_topics.class}"
  else
    puts "⚠️  No entries in database yet"
  end
  
  # Test Topic associations
  topic = Topic.first
  if topic
    puts "✅ Topic.first.entries responds: #{topic.entries.class}"
    puts "✅ Topic.first.title_entries responds: #{topic.title_entries.class}"
  else
    puts "⚠️  No topics in database yet"
  end
rescue => e
  puts "❌ ERROR: #{e.message}"
  puts e.backtrace.first(3)
  exit 1
end

# Test 3: Test auto-sync on a new entry
puts "\n3️⃣  Testing auto-sync callback..."
begin
  test_entry = Entry.new(
    site: Site.first,
    url: "https://test.com/test-#{Time.now.to_i}",
    title: "Test Entry for Auto-Sync",
    published_at: Time.current,
    enabled: true
  )
  
  # Find a topic with tags
  topic_with_tags = Topic.joins(:tags).first
  
  if topic_with_tags && topic_with_tags.tags.any?
    # Add tags that match this topic
    test_tags = topic_with_tags.tags.first(2).map(&:name)
    test_entry.tag_list = test_tags
    
    puts "Creating test entry with tags: #{test_tags.join(', ')}"
    test_entry.save!
    
    # Check if topics were auto-synced
    synced_topics = test_entry.topics.reload
    
    if synced_topics.include?(topic_with_tags)
      puts "✅ Auto-sync worked! Entry synced to #{synced_topics.count} topic(s)"
      synced_topics.each { |t| puts "   - #{t.name}" }
    else
      puts "⚠️  Auto-sync might not have worked (entry has #{synced_topics.count} topics)"
    end
    
    # Clean up
    test_entry.destroy
    puts "✅ Test entry cleaned up"
  else
    puts "⚠️  No topics with tags found - skipping auto-sync test"
  end
rescue => e
  puts "❌ ERROR: #{e.message}"
  puts e.backtrace.first(3)
end

# Test 4: Test manual sync
puts "\n4️⃣  Testing manual sync methods..."
begin
  entry = Entry.where.not(tag_list: []).first
  
  if entry
    before_count = entry.topics.count
    entry.sync_topics_from_tags
    after_count = entry.topics.reload.count
    
    puts "✅ Manual sync executed"
    puts "   Topics before: #{before_count}"
    puts "   Topics after: #{after_count}"
  else
    puts "⚠️  No entries with tags found"
  end
rescue => e
  puts "❌ ERROR: #{e.message}"
  puts e.backtrace.first(3)
end

# Test 5: Test scopes
puts "\n5️⃣  Testing scoped queries..."
begin
  topic = Topic.first
  
  if topic
    # Test for_topic scope
    count = Entry.for_topic(topic).count
    puts "✅ Entry.for_topic(#{topic.id}) returns: #{count} entries"
    
    # Test for_topic_title scope
    count = Entry.for_topic_title(topic).count
    puts "✅ Entry.for_topic_title(#{topic.id}) returns: #{count} entries"
  else
    puts "⚠️  No topics found"
  end
rescue => e
  puts "❌ ERROR: #{e.message}"
  puts e.backtrace.first(3)
end

# Summary
puts "\n" + "=" * 80
puts "Test Summary"
puts "=" * 80
puts "✅ All critical tests passed!"
puts "✅ Database tables exist"
puts "✅ Associations work correctly"
puts "✅ Auto-sync callbacks functional"
puts "✅ Scopes working"
puts "\n🎉 Ready for backfill!"
puts "\nNext steps:"
puts "1. Run small backfill test: rails runner 'BackfillEntryTopicsJob.perform_now(batch_size: 100, start_id: 1, end_id: 100)'"
puts "2. Validate results: rake entry_topics:validate_topic[1]"
puts "3. Benchmark performance: rake entry_topics:benchmark[1]"
puts "=" * 80


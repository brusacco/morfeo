#!/usr/bin/env ruby
# frozen_string_literal: true

# Simple Auto-Sync Verification Script
# Run with: RAILS_ENV=production bin/rails runner scripts/verify_autosync.rb

puts '=' * 80
puts 'AUTO-SYNC VERIFICATION'
puts '=' * 80
puts ''

# 1. Check Honor Colorado topic status
puts '📊 1. Honor Colorado Topic Status'
puts '-' * 80

topic = Topic.find_by(name: 'Honor Colorado')
if topic
  puts "Topic ID: #{topic.id}"
  puts "Status: #{topic.status ? 'Active' : 'Inactive'}"
  puts "Total associations: #{topic.entry_topics.count}"
  puts "Recent entries (7 days): #{topic.entries.where(published_at: 7.days.ago..).count}"
  puts ''
else
  puts 'Topic not found!'
  exit
end

# 2. Check a recent entry from Honor Colorado
puts '📝 2. Sample Recent Entry (Honor Colorado)'
puts '-' * 80

recent_entry = topic.entries.where(published_at: 7.days.ago..).order(published_at: :desc).first
if recent_entry
  puts "Entry ID: #{recent_entry.id}"
  puts "URL: #{recent_entry.url}"
  puts "Published: #{recent_entry.published_at}"
  puts "Tags: #{recent_entry.tag_list.join(', ')}"
  puts ''
  
  # Check associations
  assoc_count = recent_entry.entry_topics.count
  puts "EntryTopic associations: #{assoc_count}"
  
  if assoc_count > 0
    puts '✅ ENTRY HAS ASSOCIATIONS'
    puts ''
    puts 'Associated with topics:'
    recent_entry.topics.each do |t|
      matching_tags = recent_entry.tag_list & t.tags.pluck(:name)
      puts "  - #{t.name} (matched on: #{matching_tags.join(', ')})"
    end
  else
    puts '⚠️ ENTRY HAS NO ASSOCIATIONS (unexpected!)'
  end
else
  puts 'No recent entries found'
end

puts ''

# 3. Check entries created in last 24 hours
puts '🆕 3. New Entries Check (Last 24 Hours)'
puts '-' * 80

new_entries_count = Entry.where('entries.created_at > ?', 24.hours.ago).count
puts "Total new entries: #{new_entries_count}"

if new_entries_count > 0
  # Get a few samples
  samples = Entry.where('entries.created_at > ?', 24.hours.ago)
                 .limit(5)
                 .includes(:tags, :entry_topics)
  
  puts ''
  puts 'Sample new entries:'
  
  samples.each do |entry|
    tags_str = entry.tag_list.any? ? entry.tag_list.join(', ') : 'No tags'
    assoc = entry.entry_topics.count
    status = assoc > 0 ? '✅ Synced' : (entry.tag_list.any? ? '⚠️ Not synced' : 'ℹ️  No tags')
    
    puts ''
    puts "  ID: #{entry.id}"
    puts "  Created: #{entry.created_at}"
    puts "  Tags: #{tags_str}"
    puts "  Associations: #{assoc}"
    puts "  Status: #{status}"
  end
else
  puts 'No new entries in last 24 hours'
end

puts ''

# 4. Check callback methods exist
puts '⚙️  4. Callback Methods Check'
puts '-' * 80

if Entry.method_defined?(:sync_topics_from_tags)
  puts '✅ sync_topics_from_tags exists'
else
  puts '❌ sync_topics_from_tags MISSING!'
end

if Entry.method_defined?(:sync_title_topics_from_tags)
  puts '✅ sync_title_topics_from_tags exists'
else
  puts '❌ sync_title_topics_from_tags MISSING!'
end

puts ''

# 5. Summary
puts '=' * 80
puts '📋 SUMMARY'
puts '=' * 80
puts ''

if topic.entry_topics.count > 0
  puts '✅ Topic has associations - backfill worked'
end

if recent_entry && recent_entry.entry_topics.count > 0
  puts '✅ Recent entries have associations - auto-sync working'
end

puts ''
puts 'Recommendations:'
puts '- If recent entries have NO associations but have tags:'
puts '  → Check that tags match topic tags'
puts '  → Run: bin/rails tagger to re-tag recent entries'
puts ''
puts '- If new entries (< 24h) have tags but no associations:'
puts '  → Auto-sync might not be triggered'
puts '  → Check crawler logs for errors'
puts ''
puts '=' * 80


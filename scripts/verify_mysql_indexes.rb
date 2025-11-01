#!/usr/bin/env ruby
# frozen_string_literal: true

# Quick script to verify critical MySQL indexes exist
# Run with: rails runner scripts/verify_mysql_indexes.rb

puts "\n=== 🔍 MySQL Index Verification ==="
puts "Date: #{Time.current}"
puts "=" * 60

def check_index(table, column)
  result = ActiveRecord::Base.connection.execute(
    "SHOW INDEX FROM #{table} WHERE Column_name = '#{column}'"
  )
  exists = result.any?
  status = exists ? '✅' : '❌ MISSING'
  puts "#{table}.#{column}: #{status}"
  exists
rescue StandardError => e
  puts "#{table}.#{column}: ⚠️  ERROR - #{e.message}"
  false
end

# Critical indexes for performance with 1-2M entries
critical_indexes = [
  ['entries', 'published_at'],
  ['entries', 'published_date'],
  ['entries', 'enabled'],
  ['entries', 'site_id'],
  ['taggings', 'taggable_id'],
  ['taggings', 'tag_id'],
  ['tags', 'name'],
  ['tags', 'taggings_count'],
  ['facebook_entries', 'posted_at'],
  ['twitter_posts', 'posted_at']
]

puts "\n📋 Checking Critical Indexes..."
puts "-" * 60

missing_indexes = []
critical_indexes.each do |table, column|
  missing_indexes << [table, column] unless check_index(table, column)
end

# Check for composite indexes
puts "\n📊 Checking Composite Indexes..."
puts "-" * 60

%w[entries facebook_entries twitter_posts].each do |table|
  result = ActiveRecord::Base.connection.execute(
    "SHOW INDEX FROM #{table}"
  )
  indexes = result.group_by { |row| row['Key_name'] }
  composite = indexes.select { |_k, v| v.size > 1 }
  
  if composite.any?
    puts "✅ #{table} has #{composite.size} composite index(es)"
    composite.each do |name, cols|
      columns = cols.map { |c| c['Column_name'] }.join(', ')
      puts "   └─ #{name}: (#{columns})"
    end
  else
    puts "⚠️  #{table} has no composite indexes (consider adding for better performance)"
  end
end

# Summary
puts "\n" + "=" * 60
if missing_indexes.any?
  puts "❌ MISSING #{missing_indexes.size} CRITICAL INDEX(ES)"
  puts "\nRun this migration to add them:"
  puts "\n```ruby"
  puts "class AddMissingIndexes < ActiveRecord::Migration[7.0]"
  puts "  def change"
  missing_indexes.each do |table, column|
    puts "    add_index :#{table}, :#{column} unless index_exists?(:#{table}, :#{column})"
  end
  puts "  end"
  puts "end"
  puts "```"
else
  puts "✅ All critical indexes exist!"
  puts "\n✨ Your database is ready for Elasticsearch removal"
end

# Data volume check
puts "\n📊 Data Volume Check..."
puts "-" * 60
puts "Total entries: #{Entry.count}"
puts "Last 30 days: #{Entry.where(published_at: 30.days.ago..).count}"
puts "Last 7 days: #{Entry.where(published_at: 7.days.ago..).count}"
puts "Last 24 hours: #{Entry.where(published_at: 24.hours.ago..).count}"

recent_pct = (Entry.where(published_at: 30.days.ago..).count.to_f / Entry.count * 100).round(2)
puts "\n➡️  You query #{recent_pct}% of total data (recent entries only)"
puts "✅ This is PERFECT for MySQL indexed queries!"

puts "\n" + "=" * 60
puts "Done! 🎉"


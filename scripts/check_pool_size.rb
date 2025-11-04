#!/usr/bin/env ruby
# frozen_string_literal: true

# Quick check for database connection pool
require_relative '../config/environment'

puts
puts "=" * 80
puts "DATABASE CONNECTION POOL CHECK"
puts "=" * 80
puts

# Check current pool size
pool = ActiveRecord::Base.connection_pool
puts "Current Pool Size: #{pool.size}"
puts "Pool Stats: #{pool.stat.inspect}"
puts

# Check what's configured
db_config = Rails.configuration.database_configuration[Rails.env]
puts "Database Config:"
puts "  Adapter: #{db_config['adapter']}"
puts "  Database: #{db_config['database']}"
puts "  Pool (configured): #{db_config['pool']}"
puts

# Recommendations
if pool.size < 10
  puts "❌ PROBLEM: Pool size is TOO SMALL (#{pool.size})"
  puts
  puts "SOLUTION: Update config/database.yml and RESTART:"
  puts
  puts "  default: &default"
  puts "    pool: <%= ENV.fetch('RAILS_MAX_THREADS') { 20 } %>"
  puts
  puts "Then run: 'exit' and start fresh terminal/console"
  puts
elsif pool.size < 15
  puts "⚠️  WARNING: Pool size is small (#{pool.size})"
  puts "   Crawler will use only #{[pool.size - 5, 1].max} threads"
  puts "   Recommend increasing to 20 for optimal performance"
  puts
else
  puts "✅ GOOD: Pool size is adequate (#{pool.size})"
  puts "   Crawler can safely use up to 5 threads"
  puts
end

# Test connection
puts "Testing connection..."
begin
  ActiveRecord::Base.connection.execute("SELECT 1")
  puts "✅ Database connection is working"
rescue => e
  puts "❌ Database connection FAILED: #{e.message}"
end
puts

puts "=" * 80


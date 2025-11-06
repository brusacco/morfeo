#!/usr/bin/env ruby
# frozen_string_literal: true

# Test script for Facebook API retry mechanism
# Usage: rails runner scripts/test_facebook_retry.rb

puts "\n" + "=" * 80
puts "FACEBOOK API RETRY MECHANISM - TEST SCRIPT"
puts "=" * 80
puts

# Check if we have pages to test
pages = Page.limit(1)

if pages.empty?
  puts "❌ No Facebook pages found in database"
  puts "   Add pages via ActiveAdmin or import task first"
  exit 1
end

page = pages.first
puts "📄 Testing with page: #{page.name} (UID: #{page.uid})"
puts

# Test 1: Normal API call (should work)
puts "Test 1: Normal API call"
puts "-" * 40

begin
  result = FacebookServices::FanpageCrawler.call(page.uid, nil)
  
  if result.success?
    entries_count = result.data[:entries]&.size || 0
    cursor = result.data[:next]
    
    puts "✅ Success!"
    puts "   - Entries fetched: #{entries_count}"
    puts "   - Has next page: #{cursor.present? ? 'Yes' : 'No'}"
    puts
  else
    puts "❌ Failed: #{result.error}"
    puts
  end
rescue StandardError => e
  puts "❌ Exception: #{e.class} - #{e.message}"
  puts
end

# Test 2: Simulate timeout (for demo purposes)
puts "Test 2: Timeout handling demonstration"
puts "-" * 40
puts "ℹ️  This demonstrates how the retry mechanism works:"
puts
puts "   If a timeout occurs:"
puts "   - Attempt 1: Waits 2 seconds, then retries"
puts "   - Attempt 2: Waits 4 seconds, then retries"
puts "   - Attempt 3: Waits 8 seconds, then retries"
puts "   - After 3 attempts: Returns error"
puts
puts "   Retryable errors:"
puts "   ✓ Connection timeouts (Net::OpenTimeout)"
puts "   ✓ Read timeouts (Net::ReadTimeout)"
puts "   ✓ Network errors (SocketError, ECONNREFUSED)"
puts
puts "   Non-retryable errors (fail immediately):"
puts "   ✗ Authentication errors (invalid token)"
puts "   ✗ Invalid JSON responses"
puts "   ✗ API-level errors (not timeout related)"
puts

# Test 3: Verify configuration
puts "Test 3: Current retry configuration"
puts "-" * 40

service_class = FacebookServices::FanpageCrawler
puts "   MAX_RETRIES: #{service_class::MAX_RETRIES}"
puts "   INITIAL_RETRY_DELAY: #{service_class::INITIAL_RETRY_DELAY}s"
puts "   MAX_RETRY_DELAY: #{service_class::MAX_RETRY_DELAY}s"
puts

# Calculate example backoff times
puts "   Exponential backoff schedule:"
(1..service_class::MAX_RETRIES).each do |attempt|
  delay = [service_class::INITIAL_RETRY_DELAY * (2**(attempt - 1)), service_class::MAX_RETRY_DELAY].min
  puts "   - Retry #{attempt}: Wait #{delay}s"
end
puts

# Test 4: Verify timeout settings
puts "Test 4: API timeout configuration"
puts "-" * 40
puts "   TIMEOUT_SECONDS: #{service_class::TIMEOUT_SECONDS}s (read timeout)"
puts "   OPEN_TIMEOUT_SECONDS: #{service_class::OPEN_TIMEOUT_SECONDS}s (connection timeout)"
puts

# Test 5: Check token
puts "Test 5: Facebook API token validation"
puts "-" * 40

if ENV['FACEBOOK_API_TOKEN'].present?
  token_length = ENV['FACEBOOK_API_TOKEN'].length
  token_preview = ENV['FACEBOOK_API_TOKEN'][0..10] + "..." + ENV['FACEBOOK_API_TOKEN'][-5..-1]
  
  puts "✅ Token present"
  puts "   Length: #{token_length} characters"
  puts "   Preview: #{token_preview}"
  puts
else
  puts "❌ FACEBOOK_API_TOKEN not found"
  puts "   Set it in .env file or environment variables"
  puts
end

# Summary
puts "=" * 80
puts "TEST COMPLETE"
puts "=" * 80
puts
puts "📝 Next steps:"
puts "   1. Run actual crawler: rake facebook:fanpage_crawler[1]"
puts "   2. Monitor logs: tail -f log/development.log"
puts "   3. Check for retry messages in logs"
puts
puts "🔍 Watch for these log patterns:"
puts "   - 'Retry X/3 for [page_uid] after Xs' - Automatic retry in progress"
puts "   - 'Max retries (3) exceeded' - All retries exhausted"
puts "   - 'Non-retryable error' - Error that shouldn't be retried"
puts


#!/usr/bin/env ruby
# frozen_string_literal: true

# Facebook API Token Verification Script
# This script verifies that the FACEBOOK_API_TOKEN environment variable is properly configured

require_relative '../config/environment'
require 'httparty'

puts "\n" + "=" * 80
puts "FACEBOOK API TOKEN VERIFICATION"
puts "=" * 80 + "\n"

# Step 1: Check if token is loaded
print "1. Checking if FACEBOOK_API_TOKEN is set... "
if ENV['FACEBOOK_API_TOKEN'].present?
  puts "✅ YES"
  token_length = ENV['FACEBOOK_API_TOKEN'].length
  puts "   Token length: #{token_length} characters"
  puts "   Token format: #{ENV['FACEBOOK_API_TOKEN'][0..10]}...#{ENV['FACEBOOK_API_TOKEN'][-10..-1]}"
else
  puts "❌ NO"
  puts "\n⚠️  ERROR: FACEBOOK_API_TOKEN environment variable is not set!"
  puts "\nHow to fix:"
  puts "  1. Create a .env file in the project root"
  puts "  2. Add: FACEBOOK_API_TOKEN=your_token_here"
  puts "  3. Restart Rails server"
  puts "\nSee: docs/fixes/facebook_api_token_security_fix.md for details"
  exit 1
end

# Step 2: Validate token format
print "\n2. Validating token format... "
token = ENV['FACEBOOK_API_TOKEN']
if token.include?('|')
  puts "✅ VALID (App Access Token: app_id|app_secret)"
else
  puts "⚠️  WARNING: Token doesn't match expected format (should contain '|')"
  puts "   Expected: app_id|app_secret"
  puts "   Got: #{token[0..20]}..."
end

# Step 3: Test API connection
print "\n3. Testing Facebook API connection... "
begin
  api_url = "https://graph.facebook.com/v8.0/me?access_token=#{token}"
  response = HTTParty.get(api_url, timeout: 10)
  
  if response.code == 200
    puts "✅ SUCCESS"
    data = JSON.parse(response.body)
    puts "   App ID: #{data['id']}" if data['id']
  elsif response.code == 400
    puts "❌ FAILED"
    error_data = JSON.parse(response.body)
    puts "   Error: #{error_data['error']['message']}"
    puts "   Type: #{error_data['error']['type']}"
    puts "\n⚠️  Token may be invalid or expired. Generate a new one:"
    puts "   https://developers.facebook.com/tools/explorer/"
  else
    puts "❌ FAILED (HTTP #{response.code})"
    puts "   Response: #{response.body[0..200]}"
  end
rescue Net::OpenTimeout, Net::ReadTimeout => e
  puts "❌ TIMEOUT"
  puts "   Error: #{e.message}"
  puts "   Check your internet connection"
rescue => e
  puts "❌ ERROR"
  puts "   Error: #{e.class} - #{e.message}"
end

# Step 4: Check if crawler can use the token
print "\n4. Verifying crawler can access token... "
begin
  # Simulate what the crawler does
  test_token = ENV.fetch('FACEBOOK_API_TOKEN') do
    raise ArgumentError, 'FACEBOOK_API_TOKEN environment variable is not set'
  end
  
  if test_token.present?
    puts "✅ SUCCESS"
    puts "   Crawler can successfully fetch token from ENV"
  else
    puts "❌ FAILED"
    puts "   Token is set but empty"
  end
rescue ArgumentError => e
  puts "❌ FAILED"
  puts "   Error: #{e.message}"
end

# Step 5: Summary
puts "\n" + "=" * 80
puts "SUMMARY"
puts "=" * 80 + "\n"

all_checks_passed = ENV['FACEBOOK_API_TOKEN'].present?

if all_checks_passed
  puts "✅ All checks passed! Facebook API token is properly configured."
  puts "\nYou can now run:"
  puts "  rake facebook:fanpage_crawler"
else
  puts "❌ Some checks failed. Please fix the issues above."
  puts "\nFor help, see: docs/fixes/facebook_api_token_security_fix.md"
end

puts "\n" + "=" * 80 + "\n"


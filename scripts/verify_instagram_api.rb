#!/usr/bin/env ruby
# frozen_string_literal: true

# Script to test Instagram API services
# Usage: rails runner scripts/verify_instagram_api.rb

puts "=" * 80
puts "INSTAGRAM API VERIFICATION"
puts "=" * 80

# Check if token exists
if ENV['INFLUENCERS_TOKEN'].blank?
  puts "\n❌ ERROR: INFLUENCERS_TOKEN not found in environment variables"
  puts "Please set it in your .env file or environment"
  exit 1
end

puts "\n✅ INFLUENCERS_TOKEN found"

# Test username
test_username = 'ueno_py'

puts "\n" + "-" * 80
puts "Testing Profile Data Service"
puts "-" * 80

profile_result = InstagramServices::GetProfileData.call(test_username)

if profile_result.success?
  puts "\n✅ Profile API call successful!"
  puts "\nProfile Data:"
  puts "  Username: #{profile_result.data['profile_username']}"
  puts "  Name: #{profile_result.data['name']}"
  puts "  Followers: #{profile_result.data['followers_count']}"
  puts "  Following: #{profile_result.data['following_count']}"
  puts "  Posts Count: #{profile_result.data['media_count']}"
  puts "  Biography: #{profile_result.data['biography']&.truncate(100)}"
else
  puts "\n❌ Profile API call failed!"
  puts "Error: #{profile_result.error}"
end

puts "\n" + "-" * 80
puts "Testing Posts Data Service"
puts "-" * 80

posts_result = InstagramServices::GetPostsData.call(test_username)

if posts_result.success?
  puts "\n✅ Posts API call successful!"
  puts "\nPosts Data:"
  puts "  Profile Username: #{posts_result.data['profile_username']}"
  puts "  Total Posts: #{posts_result.data['total_posts']}"
  
  if posts_result.data['posts']&.any?
    puts "\nFirst Post Sample:"
    first_post = posts_result.data['posts'].first
    puts "  ID: #{first_post['id']}"
    puts "  Shortcode: #{first_post['shortcode']}"
    puts "  URL: #{first_post['url']}"
    puts "  Posted at: #{first_post['posted_at']}"
    puts "  Likes: #{first_post['likes_count']}"
    puts "  Comments: #{first_post['comments_count']}"
    puts "  Views: #{first_post['video_view_count'] || 'N/A'}"
    puts "  Total Interactions: #{first_post['total_count']}"
    puts "  Caption: #{first_post['caption']&.truncate(100)}"
    puts "  Media Type: #{first_post['media']}"
  else
    puts "\n⚠️  No posts found"
  end
else
  puts "\n❌ Posts API call failed!"
  puts "Error: #{posts_result.error}"
end

puts "\n" + "=" * 80
puts "VERIFICATION COMPLETE"
puts "=" * 80


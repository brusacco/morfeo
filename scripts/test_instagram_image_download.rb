# frozen_string_literal: true

# Quick test script to download Instagram profile image
# Usage: rails runner scripts/test_instagram_image_download.rb

puts "=" * 80
puts "INSTAGRAM IMAGE DOWNLOAD TEST"
puts "=" * 80

# Get first profile or create test one
profile = InstagramProfile.first

unless profile
  puts "\n❌ No Instagram profiles found. Create one first."
  exit 1
end

puts "\n📋 Profile Info:"
puts "  Username: @#{profile.username}"
puts "  UID: #{profile.uid}"
puts "  Name: #{profile.display_name}"

puts "\n🔗 Image URLs:"
puts "  Standard: #{profile.profile_pic_url&.truncate(80)}"
puts "  HD: #{profile.profile_pic_url_hd&.truncate(80)}"

puts "\n📁 Local Image:"
puts "  Path: #{profile.local_profile_image_path}"
puts "  Exists: #{profile.local_image_exists? ? '✅ Yes' : '❌ No'}"

if profile.local_image_exists?
  file_path = Rails.root.join('public', 'images', 'instagram', 'profiles', "#{profile.uid}.jpg")
  file_size = File.size(file_path)
  puts "  Size: #{file_size} bytes (#{(file_size / 1024.0).round(2)} KB)"
end

puts "\n" + "-" * 80
puts "Attempting to download image..."
puts "-" * 80

begin
  profile.send(:download_profile_image)
  
  if profile.local_image_exists?
    file_path = Rails.root.join('public', 'images', 'instagram', 'profiles', "#{profile.uid}.jpg")
    file_size = File.size(file_path)
    puts "\n✅ SUCCESS!"
    puts "  Image downloaded: #{file_path}"
    puts "  File size: #{file_size} bytes (#{(file_size / 1024.0).round(2)} KB)"
    
    puts "\n🌐 Access URL:"
    puts "  http://localhost:3000#{profile.local_profile_image_path}"
  else
    puts "\n❌ FAILED: Image file not created"
  end
rescue StandardError => e
  puts "\n❌ ERROR: #{e.message}"
  puts e.backtrace.first(5).join("\n")
end

puts "\n" + "=" * 80
puts "TEST COMPLETE"
puts "=" * 80


# frozen_string_literal: true

namespace :instagram do
  desc 'Test Instagram API connection'
  task test_api: :environment do
    puts "Testing Instagram API services..."
    
    username = ENV['INSTAGRAM_USERNAME'] || 'ueno_py'
    
    # Test Profile Data
    puts "\n1. Testing GetProfileData..."
    profile_result = InstagramServices::GetProfileData.call(username)
    
    if profile_result.success?
      puts "✅ Success!"
      puts "   Username: #{profile_result.data['username']}"
      puts "   Name: #{profile_result.data['full_name']}"
      puts "   Followers: #{profile_result.data['followers']}"
    else
      puts "❌ Failed: #{profile_result.error}"
    end
    
    # Test Posts Data
    puts "\n2. Testing GetPostsData..."
    posts_result = InstagramServices::GetPostsData.call(username)
    
    if posts_result.success?
      puts "✅ Success!"
      puts "   Total Posts: #{posts_result.data['total_posts']}"
      puts "   First post: #{posts_result.data['posts']&.first&.dig('shortcode')}"
    else
      puts "❌ Failed: #{posts_result.error}"
    end
  end

  desc 'Fetch profile data for a specific username'
  task :fetch_profile, [:username] => :environment do |_t, args|
    username = args[:username]
    
    unless username
      puts "Usage: rake instagram:fetch_profile[username]"
      exit 1
    end
    
    puts "Fetching profile data for @#{username}..."
    result = InstagramServices::GetProfileData.call(username)
    
    if result.success?
      puts "\n✅ Profile Data:"
      puts JSON.pretty_generate(result.data)
    else
      puts "\n❌ Error: #{result.error}"
      exit 1
    end
  end

  desc 'Fetch posts for a specific username'
  task :fetch_posts, [:username] => :environment do |_t, args|
    username = args[:username]
    
    unless username
      puts "Usage: rake instagram:fetch_posts[username]"
      exit 1
    end
    
    puts "Fetching posts for @#{username}..."
    result = InstagramServices::GetPostsData.call(username)
    
    if result.success?
      puts "\n✅ Posts Data:"
      puts "Total Posts: #{result.data['total_posts']}"
      puts "\nPosts:"
      
      result.data['posts']&.each_with_index do |post, index|
        puts "\n#{index + 1}. #{post['shortcode']}"
        puts "   URL: #{post['url']}"
        puts "   Posted: #{post['posted_at']}"
        puts "   Likes: #{post['likes_count']}, Comments: #{post['comments_count']}"
        puts "   Total: #{post['total_count']}"
        puts "   Caption: #{post['caption']&.truncate(80)}"
      end
    else
      puts "\n❌ Error: #{result.error}"
      exit 1
    end
  end

  desc 'Create or update Instagram profile'
  task :sync_profile, [:username] => :environment do |_t, args|
    username = args[:username]
    
    unless username
      puts "Usage: rake instagram:sync_profile[username]"
      exit 1
    end
    
    puts "Syncing Instagram profile @#{username}..."
    
    profile = InstagramProfile.find_or_initialize_by(username: username)
    
    if profile.new_record?
      puts "Creating new profile..."
      profile.save!
      puts "✅ Profile created successfully!"
    else
      puts "Updating existing profile..."
      profile.update_profile_data
      puts "✅ Profile updated successfully!"
    end
    
    puts "\nProfile Info:"
    puts "  ID: #{profile.id}"
    puts "  Username: @#{profile.username}"
    puts "  Name: #{profile.display_name}"
    puts "  Followers: #{profile.followers}"
    puts "  Following: #{profile.following}"
    puts "  Posts: #{profile.total_posts}"
    puts "  Engagement Rate: #{profile.engagement_rate}%"
    puts "  Verified: #{profile.is_verified ? '✓' : '✗'}"
    puts "  Last Synced: #{profile.last_synced_at}"
  rescue ActiveRecord::RecordInvalid => e
    puts "\n❌ Validation Error: #{e.message}"
    exit 1
  rescue StandardError => e
    puts "\n❌ Error: #{e.message}"
    puts e.backtrace.first(5).join("\n")
    exit 1
  end

  desc 'Test InstagramProfile model'
  task test_model: :environment do
    puts "Testing InstagramProfile model..."
    
    username = ENV['INSTAGRAM_USERNAME'] || 'ueno_py'
    
    # Clean up test data if exists
    InstagramProfile.where(username: username).destroy_all
    
    puts "\n1. Creating profile..."
    profile = InstagramProfile.create!(username: username)
    
    if profile.persisted?
      puts "✅ Profile created!"
      puts "   ID: #{profile.id}"
      puts "   Username: @#{profile.username}"
      puts "   Followers: #{profile.followers}"
      puts "   Engagement: #{profile.engagement_rate}%"
      
      # Test methods
      puts "\n2. Testing methods..."
      puts "   Instagram URL: #{profile.instagram_url}"
      puts "   Display Name: #{profile.display_name}"
      puts "   Average Engagement: #{profile.average_engagement}"
      puts "   Needs Sync?: #{profile.needs_sync?}"
      
      # Test image methods
      puts "\n3. Testing image methods..."
      puts "   Local image path: #{profile.local_profile_image_path}"
      puts "   Local image exists?: #{profile.local_image_exists?}"
      puts "   Profile image URL: #{profile.profile_image_url}"
      
      puts "\n✅ All tests passed!"
      
      # Cleanup
      print "\nDelete test profile? (y/N): "
      response = STDIN.gets.chomp.downcase
      if response == 'y'
        profile.destroy
        puts "✅ Test profile deleted"
      end
    else
      puts "❌ Failed to create profile"
      exit 1
    end
  rescue StandardError => e
    puts "\n❌ Error: #{e.message}"
    puts e.backtrace.first(5).join("\n")
    exit 1
  end

  desc 'Download images for all Instagram profiles'
  task download_images: :environment do
    puts "Downloading images for all Instagram profiles..."
    
    profiles = InstagramProfile.all
    total = profiles.count
    success = 0
    failed = 0
    
    profiles.each_with_index do |profile, index|
      print "\r[#{index + 1}/#{total}] Processing @#{profile.username}..."
      
      begin
        profile.download_profile_image
        
        if profile.local_image_exists?
          success += 1
          print " ✅"
        else
          failed += 1
          print " ❌"
        end
      rescue StandardError => e
        failed += 1
        print " ❌ (#{e.message})"
      end
      
      puts # New line
      sleep(0.5) # Be nice to Instagram servers
    end
    
    puts "\n" + "=" * 50
    puts "Download complete!"
    puts "Total: #{total}"
    puts "Success: #{success}"
    puts "Failed: #{failed}"
    puts "=" * 50
  end

  desc 'Clean up orphaned Instagram profile images'
  task cleanup_images: :environment do
    puts "Cleaning up orphaned Instagram profile images..."
    
    directory = Rails.root.join('public', 'images', 'instagram', 'profiles')
    
    unless File.directory?(directory)
      puts "Directory doesn't exist: #{directory}"
      exit 0
    end
    
    valid_uids = InstagramProfile.pluck(:uid).compact
    image_files = Dir.glob(directory.join('*.jpg'))
    
    deleted = 0
    
    image_files.each do |file_path|
      filename = File.basename(file_path, '.jpg')
      
      unless valid_uids.include?(filename)
        File.delete(file_path)
        puts "Deleted: #{filename}.jpg (no matching profile)"
        deleted += 1
      end
    end
    
    if deleted.zero?
      puts "✅ No orphaned images found"
    else
      puts "\n✅ Cleaned up #{deleted} orphaned image(s)"
    end
  end
end


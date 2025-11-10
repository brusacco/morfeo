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
      puts "   Username: #{profile_result.data['profile_username']}"
      puts "   Name: #{profile_result.data['name']}"
      puts "   Followers: #{profile_result.data['followers_count']}"
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
end


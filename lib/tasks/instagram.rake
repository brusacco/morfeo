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
    end
    
    puts "\n" + "=" * 50
    puts "Download complete!"
    puts "Total: #{total}"
    puts "Success: #{success}"
    puts "Failed: #{failed}"
    puts "=" * 50
  end

  desc 'Fix missing Instagram profile images (only download missing ones)'
  task fix_missing_images: :environment do
    puts "Checking for missing Instagram profile images..."
    
    profiles = InstagramProfile.all
    total = profiles.count
    missing = 0
    fixed = 0
    failed = 0
    
    profiles.each_with_index do |profile, index|
      unless profile.local_image_exists?
        missing += 1
        print "[#{index + 1}/#{total}] @#{profile.username} - Missing image, downloading..."
        
        begin
          if profile.download_profile_image
            fixed += 1
            puts " ✅"
          else
            failed += 1
            puts " ❌ Failed to download"
          end
        rescue StandardError => e
          failed += 1
          puts " ❌ Error: #{e.message}"
        end
      else
        print "\r[#{index + 1}/#{total}] @#{profile.username} - OK"
      end
    end
    
    puts "\n" + "=" * 50
    puts "Fix complete!"
    puts "Total profiles: #{total}"
    puts "Missing images: #{missing}"
    puts "Fixed: #{fixed}"
    puts "Failed: #{failed}"
    puts "=" * 50
  end

  desc 'Fix missing Instagram post images (only download missing ones)'
  task fix_missing_post_images: :environment do
    puts "Checking for missing Instagram post images..."
    
    posts = InstagramPost.includes(:instagram_profile).order(posted_at: :desc)
    total = posts.count
    missing = 0
    fixed = 0
    failed = 0
    
    posts.each_with_index do |post, index|
      unless post.local_image_exists?
        missing += 1
        print "[#{index + 1}/#{total}] #{post.shortcode} (@#{post.instagram_profile.username}) - Missing image, downloading..."
        
        begin
          if post.download_post_image
            fixed += 1
            puts " ✅"
          else
            failed += 1
            puts " ❌ Failed to download"
          end
        rescue StandardError => e
          failed += 1
          puts " ❌ Error: #{e.message}"
        end
      else
        print "\r[#{index + 1}/#{total}] #{post.shortcode} - OK"
      end
    end
    
    puts "\n" + "=" * 50
    puts "Fix complete!"
    puts "Total posts: #{total}"
    puts "Missing images: #{missing}"
    puts "Fixed: #{fixed}"
    puts "Failed: #{failed}"
    puts "=" * 50
  end

  desc 'Clean up orphaned Instagram images'
  task cleanup_images: :environment do
    puts "Cleaning up orphaned Instagram images..."
    
    base_directory = Rails.root.join('public', 'images', 'instagram')
    
    unless File.directory?(base_directory)
      puts "Directory doesn't exist: #{base_directory}"
      exit 0
    end
    
    valid_uids = InstagramProfile.pluck(:uid).compact
    deleted_profiles = 0
    deleted_posts = 0
    empty_dirs_removed = 0
    
    # Check each UID directory
    Dir.glob(base_directory.join('*')).each do |uid_dir|
      next unless File.directory?(uid_dir)
      
      uid = File.basename(uid_dir)
      
      unless valid_uids.include?(uid)
        FileUtils.rm_rf(uid_dir)
        puts "Deleted directory: #{uid}/ (no matching profile)"
        deleted_profiles += 1
        next
      end
      
      # Clean up post images for this profile
      profile = InstagramProfile.find_by(uid: uid)
      next unless profile
      
      valid_shortcodes = profile.instagram_posts.pluck(:shortcode).compact
      
      # Navigate through year/month/day structure
      Dir.glob(File.join(uid_dir, '*')).each do |year_dir|
        next unless File.directory?(year_dir)
        next if File.basename(year_dir) == 'avatar.jpg' # Skip avatar file
        
        # Process each year directory
        Dir.glob(File.join(year_dir, '*')).each do |month_dir|
          next unless File.directory?(month_dir)
          
          # Process each month directory
          Dir.glob(File.join(month_dir, '*')).each do |day_dir|
            next unless File.directory?(day_dir)
            
            # Process each day directory
            Dir.glob(File.join(day_dir, '*.jpg')).each do |image_path|
              shortcode = File.basename(image_path, '.jpg')
              
              unless valid_shortcodes.include?(shortcode)
                File.delete(image_path)
                relative_path = "#{uid}/#{File.basename(year_dir)}/#{File.basename(month_dir)}/#{File.basename(day_dir)}/#{shortcode}.jpg"
                puts "Deleted: #{relative_path} (no matching post)"
                deleted_posts += 1
              end
            end
            
            # Remove empty day directories
            if Dir.empty?(day_dir)
              Dir.rmdir(day_dir)
              empty_dirs_removed += 1
            end
          end
          
          # Remove empty month directories
          if Dir.empty?(month_dir)
            Dir.rmdir(month_dir)
            empty_dirs_removed += 1
          end
        end
        
        # Remove empty year directories
        if Dir.empty?(year_dir)
          Dir.rmdir(year_dir)
          empty_dirs_removed += 1
        end
      end
    end
    
    if deleted_profiles.zero? && deleted_posts.zero?
      puts "✅ No orphaned images found"
    else
      puts "\n✅ Cleanup complete:"
      puts "   Profile directories deleted: #{deleted_profiles}"
      puts "   Post images deleted: #{deleted_posts}"
      puts "   Empty directories removed: #{empty_dirs_removed}" if empty_dirs_removed > 0
    end
  end

  desc 'Migrate Instagram post images to new directory structure (year/month/day)'
  task migrate_post_images: :environment do
    puts "=" * 80
    puts "MIGRATING INSTAGRAM POST IMAGES TO NEW STRUCTURE"
    puts "=" * 80
    puts "From: /images/instagram/{uid}/{YYYY-MM-DD}/{shortcode}.jpg"
    puts "To:   /images/instagram/{uid}/{YYYY}/{MM}/{DD}/{shortcode}.jpg"
    puts "-" * 80
    
    base_directory = Rails.root.join('public', 'images', 'instagram')
    
    unless File.directory?(base_directory)
      puts "❌ Directory doesn't exist: #{base_directory}"
      exit 0
    end
    
    migrated = 0
    failed = 0
    skipped = 0
    
    # Check each UID directory
    Dir.glob(base_directory.join('*')).each do |uid_dir|
      next unless File.directory?(uid_dir)
      
      uid = File.basename(uid_dir)
      puts "\nProcessing profile: #{uid}"
      
      # Look for old date format directories (YYYY-MM-DD)
      Dir.glob(File.join(uid_dir, '*')).each do |date_dir|
        next unless File.directory?(date_dir)
        
        date_str = File.basename(date_dir)
        
        # Skip if not in YYYY-MM-DD format (e.g., skip "avatar.jpg" or year directories)
        next unless date_str =~ /^\d{4}-\d{2}-\d{2}$/
        
        puts "  Found old format directory: #{date_str}"
        
        # Parse date
        begin
          date = Date.parse(date_str)
          year = date.strftime('%Y')
          month = date.strftime('%m')
          day = date.strftime('%d')
        rescue ArgumentError
          puts "    ❌ Invalid date format: #{date_str}"
          failed += 1
          next
        end
        
        # Process each image in this directory
        Dir.glob(File.join(date_dir, '*.jpg')).each do |old_image_path|
          shortcode = File.basename(old_image_path, '.jpg')
          
          # Create new directory structure
          new_directory = Rails.root.join('public', 'images', 'instagram', uid, year, month, day)
          FileUtils.mkdir_p(new_directory) unless File.directory?(new_directory)
          
          # New file path
          new_image_path = new_directory.join("#{shortcode}.jpg")
          
          # Skip if already exists in new location
          if File.exist?(new_image_path)
            puts "    ⏭️  Skipped: #{shortcode}.jpg (already exists in new location)"
            skipped += 1
            next
          end
          
          # Move file
          begin
            FileUtils.mv(old_image_path, new_image_path)
            puts "    ✅ Migrated: #{shortcode}.jpg → #{year}/#{month}/#{day}/"
            migrated += 1
          rescue StandardError => e
            puts "    ❌ Failed to migrate #{shortcode}.jpg: #{e.message}"
            failed += 1
          end
        end
        
        # Remove old directory if empty
        begin
          if Dir.empty?(date_dir)
            Dir.rmdir(date_dir)
            puts "    🗑️  Removed empty directory: #{date_str}/"
          end
        rescue StandardError => e
          puts "    ⚠️  Could not remove directory #{date_str}/: #{e.message}"
        end
      end
    end
    
    puts "\n" + "=" * 80
    puts "MIGRATION COMPLETED"
    puts "=" * 80
    puts "Images migrated: #{migrated}"
    puts "Images skipped: #{skipped}"
    puts "Failed: #{failed}"
    puts "=" * 80
  end
end


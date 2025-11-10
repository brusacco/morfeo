# frozen_string_literal: true

namespace :instagram do
  desc 'Instagram Profiles Crawler - Updates all existing Instagram profiles'
  task profiles_crawler: :environment do
    puts "=" * 80
    puts "INSTAGRAM PROFILES CRAWLER"
    puts "=" * 80
    puts "Starting at: #{Time.current}"
    puts "-" * 80

    total_profiles = InstagramProfile.count
    processed = 0
    success = 0
    failed = 0

    InstagramProfile.find_each do |profile|
      processed += 1
      
      puts "\n[#{processed}/#{total_profiles}] Processing: #{profile.display_name} (@#{profile.username})"
      puts "  Current data:"
      puts "    Followers: #{number_with_delimiter(profile.followers)}"
      puts "    Posts: #{profile.total_posts}"
      puts "    Last synced: #{profile.last_synced_at || 'Never'}"

      begin
        profile.sync_from_api
        profile.reload
        
        puts "  ✅ Updated successfully!"
        puts "    New followers: #{number_with_delimiter(profile.followers)}"
        puts "    New posts: #{profile.total_posts}"
        puts "    Engagement: #{profile.engagement_rate}%"
        puts "    Image: #{profile.local_image_exists? ? '✅ Downloaded' : '⏳ Pending'}"
        
        success += 1
      rescue StandardError => e
        puts "  ❌ Error: #{e.message}"
        Rails.logger.error("[Instagram::ProfilesCrawler] Error updating @#{profile.username}: #{e.message}")
        failed += 1
      end

      puts "  " + "-" * 76
    end

    puts "\n" + "=" * 80
    puts "CRAWLER COMPLETED"
    puts "=" * 80
    puts "Total profiles: #{total_profiles}"
    puts "Success: #{success}"
    puts "Failed: #{failed}"
    puts "Finished at: #{Time.current}"
    puts "=" * 80
  end

  desc 'Instagram Posts Crawler - Fetches posts for all Instagram profiles'
  task posts_crawler: :environment do
    puts "=" * 80
    puts "INSTAGRAM POSTS CRAWLER"
    puts "=" * 80
    puts "Starting at: #{Time.current}"
    puts "-" * 80

    total_profiles = InstagramProfile.count
    processed = 0
    total_posts_created = 0
    total_posts_updated = 0
    failed_profiles = 0

    InstagramProfile.find_each do |profile|
      processed += 1
      
      puts "\n[#{processed}/#{total_profiles}] Processing: #{profile.display_name} (@#{profile.username})"
      puts "  Current posts in DB: #{profile.instagram_posts.count}"
      puts "  Latest post in DB: #{profile.instagram_posts.order(posted_at: :desc).first&.posted_at || 'None'}"

      begin
        # Process posts (update existing metrics)
        response = InstagramServices::ProcessPosts.call(profile.username, update_existing: true)

        unless response.success?
          puts "  ❌ Error crawling #{profile.username}: #{response.error}"
          failed_profiles += 1
          next
        end

        data = response.data || {}
        posts = data[:posts] || []
        message = data[:message]

        if posts.empty?
          puts "  ⚠️  No posts to process for #{profile.username}"
        else
          # Count new vs updated
          new_posts = posts.select { |p| p.created_at == p.updated_at }.count
          updated_posts = posts.count - new_posts
          
          total_posts_created += new_posts
          total_posts_updated += updated_posts
          
          total_count = profile.instagram_posts.count
          latest = profile.instagram_posts.order(posted_at: :desc).first

          puts "  ✅ Processed #{posts.count} posts for #{profile.username}"
          puts "    New: #{new_posts}, Updated: #{updated_posts}"
          puts "    Total posts now: #{total_count}"
          puts "    Latest post: #{latest.posted_at}" if latest

          # Show the 3 most recent with engagement metrics
          posts.sort_by(&:posted_at).reverse.first(3).each do |post|
            tag_info = post.tags.any? ? " | 🏷️  #{post.tag_list.join(', ')}" : ""
            link_info = post.entry.present? ? " | 🔗 Entry #{post.entry_id}" : ""
            views_info = post.video_view_count.present? ? " | 👁️  #{number_with_delimiter(post.video_view_count)}" : ""
            puts "      #{post.post_type} #{post.shortcode} (#{post.posted_at.strftime('%Y-%m-%d')})"
            puts "        ❤️  #{number_with_delimiter(post.likes_count)} | 💬 #{post.comments_count}#{views_info}#{link_info}#{tag_info}"
          end
        end
      rescue StandardError => e
        puts "  ❌ Exception: #{e.message}"
        Rails.logger.error("[Instagram::PostsCrawler] Error processing @#{profile.username}: #{e.message}")
        Rails.logger.error(e.backtrace.first(5).join("\n"))
        failed_profiles += 1
      end

      puts "  " + "-" * 76
    end

    puts "\n" + "=" * 80
    puts "CRAWLER COMPLETED"
    puts "=" * 80
    puts "Profiles processed: #{processed}"
    puts "Posts created: #{total_posts_created}"
    puts "Posts updated: #{total_posts_updated}"
    puts "Failed profiles: #{failed_profiles}"
    puts "Finished at: #{Time.current}"
    puts "=" * 80
  end

  private

  def self.number_with_delimiter(number)
    return '0' if number.nil?
    number.to_s.reverse.gsub(/(\d{3})(?=\d)/, '\\1,').reverse
  end
end


# frozen_string_literal: true

namespace :instagram do
  desc 'Instagram Tagger - Tag or re-tag posts based on caption content'
  task tagger: :environment do
    puts "=" * 80
    puts "INSTAGRAM POSTS TAGGER"
    puts "=" * 80
    puts "Starting at: #{Time.current}"
    puts "-" * 80
    
    # Get all posts without tags or with very few tags
    posts = InstagramPost.includes(:instagram_profile, :entry, :tags).order(posted_at: :desc)
    total = posts.count
    processed = 0
    tagged = 0
    already_tagged = 0
    no_tags_found = 0
    
    # Load all tags once for performance
    all_tags = Tag.all.to_a
    
    posts.each_with_index do |post, index|
      processed += 1
      print "\r[#{processed}/#{total}] Processing #{post.shortcode}..."
      
      # Skip if already has tags (unless forced)
      if post.tags.any? && ENV['FORCE'] != 'true'
        already_tagged += 1
        next
      end
      
      begin
        tags_found = []
        caption_lower = post.caption.to_s.downcase
        
        # Check all tags
        all_tags.each do |tag|
          tag_names = [tag.name, tag.variations].flatten.compact.map(&:downcase)
          
          if tag_names.any? { |name| caption_lower.include?(name) }
            tags_found << tag.name
          end
        end
        
        # If no tags found through text matching, try to inherit from linked entry
        if tags_found.empty? && post.entry.present? && post.entry.tag_list.any?
          entry_tags = post.entry.tag_list.dup
          entry_tags.delete('Instagram')
          
          if entry_tags.any?
            post.tag_list = entry_tags
            post.save!
            puts "\r[#{processed}/#{total}] ✅ #{post.shortcode} - Tagged with inherited tags: #{entry_tags.join(', ')}"
            tagged += 1
            next
          end
        end
        
        # Apply found tags
        if tags_found.any?
          tags_found.delete('Instagram')
          post.tag_list = tags_found
          post.save!
          puts "\r[#{processed}/#{total}] ✅ #{post.shortcode} - Tagged: #{tags_found.join(', ')}"
          tagged += 1
        else
          no_tags_found += 1
        end
        
      rescue StandardError => e
        puts "\r[#{processed}/#{total}] ❌ Error tagging #{post.shortcode}: #{e.message}"
        Rails.logger.error("[Instagram::Tagger] Error: #{e.message}")
      end
    end
    
    puts "\n" + "=" * 80
    puts "TAGGER COMPLETED"
    puts "=" * 80
    puts "Total posts: #{total}"
    puts "Already tagged (skipped): #{already_tagged}"
    puts "Newly tagged: #{tagged}"
    puts "No tags found: #{no_tags_found}"
    puts "Finished at: #{Time.current}"
    puts "=" * 80
    puts ""
    puts "💡 Tip: Run with FORCE=true to re-tag all posts (even those already tagged)"
    puts "   Example: FORCE=true bundle exec rake instagram:tagger"
  end
end


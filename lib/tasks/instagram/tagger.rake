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

    posts.each_with_index do |post, index|
      processed += 1
      print "\r[#{processed}/#{total}] Processing #{post.shortcode}..."

      # Skip if already has tags (unless forced)
      if post.tags.any? && ENV['FORCE'] != 'true'
        already_tagged += 1
        next
      end

      begin
        # Use ExtractTags service
        result = InstagramServices::ExtractTags.call(post.id)

        if result.success?
          tags = result.data
          puts "\r[#{processed}/#{total}] ✅ #{post.shortcode} - Tagged: #{tags.join(', ')}"
          tagged += 1
        else
          # No tags found
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


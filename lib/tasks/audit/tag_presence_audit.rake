# frozen_string_literal: true

namespace :audit do
  namespace :tag do
    desc 'Audit tag presence across different time periods (7, 15, 30, 60 days)'
    task :presence, [:tag_id] => :environment do |_t, args|
      unless args[:tag_id]
        puts "❌ Error: TAG_ID is required"
        puts "Usage: rake 'audit:tag:presence[TAG_ID]'"
        exit 1
      end

      tag_id = args[:tag_id].to_i
      tag = ActsAsTaggableOn::Tag.find_by(id: tag_id)

      unless tag
        puts "❌ Error: Tag with ID #{tag_id} not found"
        exit 1
      end

      puts "=" * 80
      puts "🔍 TAG PRESENCE AUDIT"
      puts "=" * 80
      puts "Tag ID: #{tag.id}"
      puts "Tag Name: #{tag.name}"
      puts "Audit Time: #{Time.current.strftime('%Y-%m-%d %H:%M:%S')}"
      puts "=" * 80
      puts

      # Time periods to check
      periods = [
        { days: 7, label: 'Last 7 days' },
        { days: 15, label: 'Last 15 days' },
        { days: 30, label: 'Last 30 days' },
        { days: 60, label: 'Last 60 days' }
      ]

      # Check each period
      periods.each do |period|
        puts "📅 #{period[:label].upcase}"
        puts "-" * 80

        start_date = period[:days].days.ago.beginning_of_day
        end_date = Time.current.end_of_day

        # Digital Media (Entry)
        entries = Entry.enabled
                       .where(published_at: start_date..end_date)
                       .tagged_with(tag.name, any: true)
                       .distinct

        entries_count = entries.count('DISTINCT entries.id')
        entries_interactions = entries_count > 0 ? entries.sum(:total_count) : 0

        puts "  📰 Digital Media (Entry):"
        puts "     Mentions: #{entries_count}"
        puts "     Interactions: #{entries_interactions}"
        
        if entries_count > 0
          # Sample entries
          sample_entries = entries.order(published_at: :desc).limit(3)
          puts "     Sample entries:"
          sample_entries.each do |entry|
            puts "       - [#{entry.published_at.strftime('%Y-%m-%d')}] #{entry.title[0..60]}... (#{entry.total_count} interactions)"
          end
        end
        puts

        # Facebook
        fb_entries = FacebookEntry.where(posted_at: start_date..end_date)
                                  .tagged_with(tag.name, any: true)
                                  .includes(:page)
                                  .distinct

        fb_count = fb_entries.count('DISTINCT facebook_entries.id')
        fb_interactions = fb_count > 0 ? fb_entries.sum('reactions_total_count + comments_count + share_count') : 0
        fb_reach = fb_count > 0 ? fb_entries.sum(:views_count) : 0

        puts "  📘 Facebook (FacebookEntry):"
        puts "     Mentions: #{fb_count}"
        puts "     Interactions: #{fb_interactions}"
        puts "     Reach (actual views): #{fb_reach}"
        
        if fb_count > 0
          # Sample posts
          sample_fb = fb_entries.order(posted_at: :desc).limit(3)
          puts "     Sample posts:"
          sample_fb.each do |fb|
            total_interactions = fb.reactions_total_count + fb.comments_count + fb.share_count
            puts "       - [#{fb.posted_at.strftime('%Y-%m-%d')}] #{fb.page&.name} - #{fb.message&.truncate(60) || '(no message)'} (#{total_interactions} interactions)"
          end
        end
        puts

        # Twitter
        tweets = TwitterPost.where(posted_at: start_date..end_date)
                           .tagged_with(tag.name, any: true)
                           .includes(:twitter_profile)
                           .distinct

        tweets_count = tweets.count('DISTINCT twitter_posts.id')
        tweets_interactions = tweets_count > 0 ? tweets.sum('favorite_count + retweet_count + reply_count + quote_count') : 0
        tweets_views = tweets_count > 0 ? tweets.sum(:views_count) : 0

        puts "  🐦 Twitter (TwitterPost):"
        puts "     Mentions: #{tweets_count}"
        puts "     Interactions: #{tweets_interactions}"
        puts "     Views: #{tweets_views > 0 ? "#{tweets_views} (actual)" : '0 (using fallback)'}"
        
        if tweets_count > 0
          # Sample tweets
          sample_tweets = tweets.order(posted_at: :desc).limit(3)
          puts "     Sample tweets:"
          sample_tweets.each do |tweet|
            total_interactions = tweet.favorite_count + tweet.retweet_count + tweet.reply_count + tweet.quote_count
            puts "       - [#{tweet.posted_at.strftime('%Y-%m-%d')}] @#{tweet.twitter_profile&.username} - #{tweet.text&.truncate(60)} (#{total_interactions} interactions)"
          end
        end
        puts

        # Summary
        total_mentions = entries_count + fb_count + tweets_count
        total_interactions = entries_interactions + fb_interactions + tweets_interactions
        
        puts "  📊 PERIOD SUMMARY:"
        puts "     Total Mentions: #{total_mentions}"
        puts "     Total Interactions: #{total_interactions}"
        puts "     Channels Active: #{[entries_count > 0, fb_count > 0, tweets_count > 0].count(true)}/3"
        puts "=" * 80
        puts
      end

      # Overall tag statistics
      puts "📈 OVERALL TAG STATISTICS (ALL TIME)"
      puts "-" * 80

      total_entries = Entry.enabled.tagged_with(tag.name, any: true).distinct.count('DISTINCT entries.id')
      total_fb = FacebookEntry.tagged_with(tag.name, any: true).distinct.count('DISTINCT facebook_entries.id')
      total_tweets = TwitterPost.tagged_with(tag.name, any: true).distinct.count('DISTINCT twitter_posts.id')

      puts "  Total Digital Media entries: #{total_entries}"
      puts "  Total Facebook posts: #{total_fb}"
      puts "  Total Twitter posts: #{total_tweets}"
      puts "  Grand Total: #{total_entries + total_fb + total_tweets}"
      puts

      # Topics using this tag
      topics = Topic.joins(:tags).where('tags.id = ?', tag.id).pluck(:id, :name)
      
      if topics.any?
        puts "  🏷️  Topics using this tag (#{topics.size}):"
        topics.each do |topic_id, topic_name|
          puts "     - [#{topic_id}] #{topic_name}"
        end
      else
        puts "  ⚠️  WARNING: This tag is not associated with any topics!"
      end
      
      puts "=" * 80
      puts "✅ Audit complete!"
      puts
    end

    desc 'Audit ALL tags for a specific period'
    task :bulk_presence, [:days] => :environment do |_t, args|
      days = args[:days]&.to_i || 30
      
      puts "=" * 80
      puts "🔍 BULK TAG PRESENCE AUDIT"
      puts "=" * 80
      puts "Period: Last #{days} days"
      puts "Audit Time: #{Time.current.strftime('%Y-%m-%d %H:%M:%S')}"
      puts "=" * 80
      puts

      start_date = days.days.ago.beginning_of_day
      end_date = Time.current.end_of_day

      # Get all tags
      all_tags = ActsAsTaggableOn::Tag.order(:name)

      puts "Total tags to audit: #{all_tags.count}"
      puts

      results = []

      all_tags.each_with_index do |tag, index|
        print "\rProgress: #{index + 1}/#{all_tags.count} - Checking '#{tag.name}'...".ljust(100)

        # Check each channel
        entries_count = Entry.enabled
                             .where(published_at: start_date..end_date)
                             .tagged_with(tag.name, any: true)
                             .distinct
                             .count('DISTINCT entries.id')

        fb_count = FacebookEntry.where(posted_at: start_date..end_date)
                                .tagged_with(tag.name, any: true)
                                .distinct
                                .count('DISTINCT facebook_entries.id')

        tweets_count = TwitterPost.where(posted_at: start_date..end_date)
                                  .tagged_with(tag.name, any: true)
                                  .distinct
                                  .count('DISTINCT twitter_posts.id')

        total_mentions = entries_count + fb_count + tweets_count

        topics_count = Topic.joins(:tags).where('tags.id = ?', tag.id).count

        results << {
          tag_id: tag.id,
          tag_name: tag.name,
          entries: entries_count,
          facebook: fb_count,
          twitter: tweets_count,
          total: total_mentions,
          topics: topics_count,
          active: total_mentions > 0
        }
      end

      puts "\n"
      puts "=" * 80
      puts "📊 RESULTS"
      puts "=" * 80
      puts

      # Active tags
      active_tags = results.select { |r| r[:active] }
      inactive_tags = results.reject { |r| r[:active] }

      puts "✅ Active Tags (#{active_tags.size}):"
      puts "-" * 80
      puts sprintf("%-6s %-30s %10s %10s %10s %10s %8s", "ID", "Tag Name", "Digital", "Facebook", "Twitter", "Total", "Topics")
      puts "-" * 80
      
      active_tags.sort_by { |r| -r[:total] }.each do |result|
        puts sprintf(
          "%-6d %-30s %10d %10d %10d %10d %8d",
          result[:tag_id],
          result[:tag_name].truncate(30),
          result[:entries],
          result[:facebook],
          result[:twitter],
          result[:total],
          result[:topics]
        )
      end
      puts

      puts "⚠️  Inactive Tags (#{inactive_tags.size}):"
      puts "-" * 80
      inactive_tags.sort_by { |r| r[:tag_name] }.first(20).each do |result|
        status = result[:topics] > 0 ? "[#{result[:topics]} topics]" : "[NO TOPICS]"
        puts "  - [#{result[:tag_id]}] #{result[:tag_name]} #{status}"
      end
      
      if inactive_tags.size > 20
        puts "  ... and #{inactive_tags.size - 20} more"
      end
      puts

      puts "=" * 80
      puts "📈 SUMMARY"
      puts "=" * 80
      puts "Total Tags: #{results.size}"
      puts "Active Tags (with content): #{active_tags.size} (#{(active_tags.size.to_f / results.size * 100).round(1)}%)"
      puts "Inactive Tags (no content): #{inactive_tags.size} (#{(inactive_tags.size.to_f / results.size * 100).round(1)}%)"
      puts
      puts "Tags without topics: #{results.count { |r| r[:topics].zero? }}"
      puts "Tags with no content but assigned to topics: #{inactive_tags.count { |r| r[:topics] > 0 }}"
      puts "=" * 80
      puts "✅ Bulk audit complete!"
      puts
    end
  end
end


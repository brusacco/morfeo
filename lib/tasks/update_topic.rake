# frozen_string_literal: true

namespace :topic do
  desc 'Update all data for a specific topic (caches, tags, relations, stats)'
  task :update, [:topic_id, :days] => :environment do |_t, args|
    # ============================================
    # PARAMETER VALIDATION
    # ============================================
    
    topic_id = args[:topic_id]
    days = (args[:days] || DAYS_RANGE || 7).to_i
    
    unless topic_id
      puts "❌ Error: Please provide a topic ID"
      puts "\nUsage:"
      puts "  rake topic:update[TOPIC_ID]              # Update last #{DAYS_RANGE} days (default)"
      puts "  rake topic:update[TOPIC_ID,15]           # Update last 15 days"
      puts "  rake topic:update[TOPIC_ID,30]           # Update last 30 days"
      puts "  rake topic:update[TOPIC_ID,60]           # Update last 60 days"
      puts "\nExample:"
      puts "  rake topic:update[1]                     # Update topic #1 (last #{DAYS_RANGE} days)"
      puts "  rake topic:update[1,30]                  # Update topic #1 (last 30 days)"
      puts "  rake topic:update[1,60]                  # Update topic #1 (last 60 days - full PDF range)"
      exit 1
    end
    
    # Find topic
    begin
      topic = Topic.find(topic_id)
    rescue ActiveRecord::RecordNotFound
      puts "❌ Error: Topic ##{topic_id} not found"
      exit 1
    end
    
    # ============================================
    # START UPDATE PROCESS
    # ============================================
    
    puts "\n" + "=" * 80
    puts "🚀 UPDATING TOPIC: #{topic.name} (ID: #{topic.id})"
    puts "=" * 80
    puts "📅 Date Range: Last #{days} days (#{days.days.ago.to_date} - #{Date.current})"
    puts "🏷️  Topic Tags: #{topic.tags.pluck(:name).join(', ')}"
    puts "=" * 80
    
    start_time = Time.current
    tag_names = topic.tags.pluck(:name)
    
    if tag_names.empty?
      puts "\n⚠️  WARNING: Topic has no tags. Some operations will be skipped."
    end
    
    # ============================================
    # STEP 1: CLEAR TOPIC CACHES
    # ============================================
    
    puts "\n📍 STEP 1/6: Clearing topic caches..."
    puts "-" * 80
    
    # Clear Redis service caches (dashboard data)
    service_cache_patterns = [
      "topic_#{topic.id}_*",
      "digital_dashboard_#{topic.id}_*",
      "facebook_dashboard_#{topic.id}_*", 
      "twitter_dashboard_#{topic.id}_*",
      "general_dashboard_#{topic.id}_*"
    ]
    
    service_cache_patterns.each do |pattern|
      deleted_count = Rails.cache.delete_matched(pattern)
      puts "   ✅ Cleared service cache: #{pattern}"
    end
    
    # Clear action caches (rendered views)
    action_cache_patterns = [
      "views/topic/show/topic_id=#{topic.id}*",
      "views/topic/pdf/topic_id=#{topic.id}*",
      "views/general_dashboard/show/topic_id=#{topic.id}*",
      "views/general_dashboard/pdf/topic_id=#{topic.id}*",
      "views/facebook_topic/show/topic_id=#{topic.id}*",
      "views/facebook_topic/pdf/topic_id=#{topic.id}*",
      "views/twitter_topic/show/topic_id=#{topic.id}*",
      "views/twitter_topic/pdf/topic_id=#{topic.id}*"
    ]
    
    action_cache_patterns.each do |pattern|
      deleted_count = Rails.cache.delete_matched(pattern)
      puts "   ✅ Cleared action cache: #{pattern}"
    end
    
    puts "✅ Step 1 Complete: All Redis and action caches cleared"
    
    # ============================================
    # STEP 2: RETAG DIGITAL ENTRIES
    # ============================================
    
    puts "\n📍 STEP 2/6: Retagging digital entries..."
    puts "-" * 80
    
    entries_scope = Entry.enabled.where(published_at: days.days.ago..Time.current)
    entries_total = entries_scope.count
    entries_tagged = 0
    entries_failed = 0
    
    puts "   📊 Found #{entries_total} entries to process"
    
    if entries_total > 0
      entries_scope.find_each.with_index do |entry, index|
        begin
          result = WebExtractorServices::ExtractTags.call(entry.id)
          
          if result.success?
            entry.tag_list = result.data
            entry.save!
            entries_tagged += 1
            
            # Force sync topics even if tags didn't change
            entry.sync_topics_from_tags if entry.respond_to?(:sync_topics_from_tags)
            entry.sync_title_topics_from_tags if entry.respond_to?(:sync_title_topics_from_tags)
          else
            entries_failed += 1
          end
          
          # Progress indicator
          if (index + 1) % 50 == 0
            puts "   ⏳ Progress: #{index + 1}/#{entries_total} entries..."
          end
          
        rescue StandardError => e
          puts "   ⚠️  Entry ##{entry.id} failed: #{e.message}"
          entries_failed += 1
        end
      end
    end
    
    puts "   ✅ Tagged: #{entries_tagged} entries"
    puts "   ⚠️  Failed: #{entries_failed} entries" if entries_failed > 0
    puts "✅ Step 2 Complete: Digital entries retagged"
    
    # ============================================
    # STEP 3: RETAG FACEBOOK ENTRIES
    # ============================================
    
    puts "\n📍 STEP 3/6: Retagging Facebook entries..."
    puts "-" * 80
    
    fb_scope = FacebookEntry.where(posted_at: days.days.ago..Time.current)
    fb_total = fb_scope.count
    fb_tagged = 0
    fb_failed = 0
    fb_inherited = 0
    
    puts "   📊 Found #{fb_total} Facebook entries to process"
    
    if fb_total > 0
      fb_scope.find_each.with_index do |facebook_entry, index|
        begin
          result = WebExtractorServices::ExtractFacebookEntryTags.call(facebook_entry.id)
          
          # If no tags found, try inheriting from linked entry
          if !result.success? && facebook_entry.entry.present? && facebook_entry.entry.tag_list.any?
            entry_tags = facebook_entry.entry.tag_list.dup
            entry_tags.delete('Facebook')
            entry_tags.delete('WhatsApp')
            
            facebook_entry.tag_list = entry_tags
            facebook_entry.save!
            fb_inherited += 1
            fb_tagged += 1
          elsif result.success?
            result.data.delete('Facebook')
            result.data.delete('WhatsApp')
            
            facebook_entry.tag_list = result.data
            facebook_entry.save!
            fb_tagged += 1
          else
            fb_failed += 1
          end
          
          # Progress indicator
          if (index + 1) % 50 == 0
            puts "   ⏳ Progress: #{index + 1}/#{fb_total} Facebook entries..."
          end
          
        rescue StandardError => e
          puts "   ⚠️  Facebook entry #{facebook_entry.facebook_post_id} failed: #{e.message}"
          fb_failed += 1
        end
      end
    end
    
    puts "   ✅ Tagged: #{fb_tagged} entries (#{fb_inherited} inherited from linked entries)"
    puts "   ⚠️  Failed: #{fb_failed} entries" if fb_failed > 0
    puts "✅ Step 3 Complete: Facebook entries retagged"
    
    # ============================================
    # STEP 4: RETAG TWITTER POSTS
    # ============================================
    
    puts "\n📍 STEP 4/6: Retagging Twitter posts..."
    puts "-" * 80
    
    tw_scope = TwitterPost.where(posted_at: days.days.ago..Time.current)
    tw_total = tw_scope.count
    tw_tagged = 0
    tw_failed = 0
    tw_inherited = 0
    
    puts "   📊 Found #{tw_total} Twitter posts to process"
    
    if tw_total > 0
      tw_scope.find_each.with_index do |twitter_post, index|
        begin
          result = TwitterServices::ExtractTags.call(twitter_post.id)
          
          # If no tags found, try inheriting from linked entry
          if !result.success? && twitter_post.entry.present? && twitter_post.entry.tag_list.any?
            entry_tags = twitter_post.entry.tag_list.dup
            entry_tags.delete('Twitter')
            
            twitter_post.tag_list = entry_tags
            twitter_post.save!
            tw_inherited += 1
            tw_tagged += 1
          elsif result.success?
            result.data.delete('Twitter')
            
            twitter_post.tag_list = result.data
            twitter_post.save!
            tw_tagged += 1
          else
            tw_failed += 1
          end
          
          # Progress indicator
          if (index + 1) % 50 == 0
            puts "   ⏳ Progress: #{index + 1}/#{tw_total} Twitter posts..."
          end
          
        rescue StandardError => e
          puts "   ⚠️  Twitter post #{twitter_post.tweet_id} failed: #{e.message}"
          tw_failed += 1
        end
      end
    end
    
    puts "   ✅ Tagged: #{tw_tagged} posts (#{tw_inherited} inherited from linked entries)"
    puts "   ⚠️  Failed: #{tw_failed} posts" if tw_failed > 0
    puts "✅ Step 4 Complete: Twitter posts retagged"
    
    # ============================================
    # STEP 5: SYNC ENTRY-TOPIC RELATIONS
    # ============================================
    
    puts "\n📍 STEP 5/6: Syncing entry-topic relations..."
    puts "-" * 80
    
    # Sync regular tags (entry_topics)
    entries_with_tags = Entry.enabled
                             .where(published_at: days.days.ago..Time.current)
                             .tagged_with(tag_names, any: true)
    
    synced_count = 0
    
    entries_with_tags.find_each do |entry|
      matching_topics = Topic.joins(:tags)
                            .where(tags: { name: entry.tag_list })
                            .distinct
      
      entry.topics = matching_topics
      synced_count += 1
    end
    
    puts "   ✅ Synced #{synced_count} entries with topics (via entry_topics)"
    
    # Sync title tags (entry_title_topics)
    entries_with_title_tags = Entry.enabled
                                   .where(published_at: days.days.ago..Time.current)
                                   .tagged_with(tag_names, any: true, on: :title_tags)
    
    title_synced_count = 0
    
    entries_with_title_tags.find_each do |entry|
      matching_topics = Topic.joins(:tags)
                            .where(tags: { name: entry.title_tag_list })
                            .distinct
      
      entry.title_topics = matching_topics
      title_synced_count += 1
    end
    
    puts "   ✅ Synced #{title_synced_count} entries with topics (via entry_title_topics)"
    puts "✅ Step 5 Complete: Entry-topic relations synced"
    
    # ============================================
    # STEP 6: UPDATE DAILY STATISTICS
    # ============================================
    
    puts "\n📍 STEP 6/6: Updating daily statistics..."
    puts "-" * 80
    
    date_range = days.days.ago.to_date..Date.current
    stats_updated = 0
    
    # Wrap each day's updates in a transaction for atomicity
    date_range.each do |day_date|
      ActiveRecord::Base.transaction do
        # Regular tags statistics
        entry_quantity = Entry.enabled.tagged_on_entry_quantity(tag_names, day_date)
        entry_interaction = Entry.enabled.tagged_on_entry_interaction(tag_names, day_date)
        
        average = entry_quantity > 0 ? entry_interaction / entry_quantity : 0
        
        neutral_quantity = Entry.enabled.tagged_on_neutral_quantity(tag_names, day_date)
        positive_quantity = Entry.enabled.tagged_on_positive_quantity(tag_names, day_date)
        negative_quantity = Entry.enabled.tagged_on_negative_quantity(tag_names, day_date)
        
        neutral_interaction = Entry.enabled.tagged_on_neutral_interaction(tag_names, day_date)
        positive_interaction = Entry.enabled.tagged_on_positive_interaction(tag_names, day_date)
        negative_interaction = Entry.enabled.tagged_on_negative_interaction(tag_names, day_date)
        
        stat = TopicStatDaily.find_or_create_by(topic_id: topic.id, topic_date: day_date)
        stat.update!(
          entry_count: entry_quantity,
          total_count: entry_interaction,
          average: average,
          neutral_quantity: neutral_quantity,
          positive_quantity: positive_quantity,
          negative_quantity: negative_quantity,
          neutral_interaction: neutral_interaction,
          positive_interaction: positive_interaction,
          negative_interaction: negative_interaction
        )
        
        # Title tags statistics
        title_entry_quantity = Entry.enabled.tagged_on_title_entry_quantity(tag_names, day_date)
        title_entry_interaction = Entry.enabled.tagged_on_title_entry_interaction(tag_names, day_date)
        
        title_stat = TitleTopicStatDaily.find_or_create_by(topic_id: topic.id, topic_date: day_date)
        title_stat.update!(
          entry_quantity: title_entry_quantity,
          entry_interaction: title_entry_interaction
        )
      end
      
      stats_updated += 1
    end
    
    puts "   ✅ Updated statistics for #{stats_updated} days"
    puts "✅ Step 6 Complete: Daily statistics updated"
    
    # ============================================
    # FINAL SUMMARY
    # ============================================
    
    duration = (Time.current - start_time).round(2)
    
    puts "\n" + "=" * 80
    puts "🎉 TOPIC UPDATE COMPLETE!"
    puts "=" * 80
    puts "📊 Summary:"
    puts "   Topic: #{topic.name} (ID: #{topic.id})"
    puts "   Date Range: #{days} days (#{days.days.ago.to_date} - #{Date.current})"
    puts "   Duration: #{duration} seconds (#{(duration / 60).round(2)} minutes)"
    puts ""
    puts "   📰 Digital Entries:"
    puts "      • Total: #{entries_total}"
    puts "      • Tagged: #{entries_tagged}"
    puts "      • Failed: #{entries_failed}" if entries_failed > 0
    puts ""
    puts "   📘 Facebook Entries:"
    puts "      • Total: #{fb_total}"
    puts "      • Tagged: #{fb_tagged}"
    puts "      • Inherited: #{fb_inherited}"
    puts "      • Failed: #{fb_failed}" if fb_failed > 0
    puts ""
    puts "   🐦 Twitter Posts:"
    puts "      • Total: #{tw_total}"
    puts "      • Tagged: #{tw_tagged}"
    puts "      • Inherited: #{tw_inherited}"
    puts "      • Failed: #{tw_failed}" if tw_failed > 0
    puts ""
    puts "   🔗 Relations:"
    puts "      • Entry-Topics synced: #{synced_count}"
    puts "      • Title-Topics synced: #{title_synced_count}"
    puts ""
    puts "   📈 Statistics:"
    puts "      • Days updated: #{stats_updated}"
    puts ""
    puts "   🧹 Caches:"
    puts "      • All topic caches cleared"
    puts "=" * 80
    
    # ============================================
    # OPTIONAL: WARM CACHES
    # ============================================
    
    puts "\n🔥 Warming caches for topic..."
    
    begin
      # Warm digital dashboard (use actual 'days' parameter, not DAYS_RANGE)
      DigitalDashboardServices::AggregatorService.call(topic: topic, days_range: days)
      puts "   ✅ Digital dashboard cache warmed (#{days} days)"
      
      # Warm Facebook dashboard
      FacebookDashboardServices::AggregatorService.call(
        topic: topic,
        top_posts_limit: 20,
        days_range: days
      )
      puts "   ✅ Facebook dashboard cache warmed (#{days} days)"
      
      # Warm Twitter dashboard
      TwitterDashboardServices::AggregatorService.call(
        topic: topic,
        top_posts_limit: 20,
        days_range: days
      )
      puts "   ✅ Twitter dashboard cache warmed (#{days} days)"
      
      # Warm General dashboard
      GeneralDashboardServices::AggregatorService.call(
        topic: topic,
        start_date: days.days.ago.beginning_of_day,
        end_date: Time.zone.now.end_of_day
      )
      puts "   ✅ General dashboard cache warmed (#{days} days)"
      
    rescue StandardError => e
      puts "   ⚠️  Warning: Cache warming failed: #{e.message}"
    end
    
    puts "\n" + "=" * 80
    puts "✅ All done! Topic '#{topic.name}' is fully updated and ready to use."
    puts "=" * 80
    puts ""
    
  rescue StandardError => e
    puts "\n❌ FATAL ERROR: #{e.message}"
    puts e.backtrace.first(10).join("\n")
    exit 1
  end
  
  # ============================================
  # HELPER TASK: UPDATE MULTIPLE TOPICS
  # ============================================
  
  desc 'Update multiple topics by ID (comma-separated)'
  task :update_multiple, [:topic_ids, :days] => :environment do |_t, args|
    topic_ids = args[:topic_ids]
    days = args[:days] || DAYS_RANGE
    
    unless topic_ids
      puts "❌ Error: Please provide topic IDs (comma-separated)"
      puts "\nUsage:"
      puts "  rake topic:update_multiple[1,2,3]           # Update topics 1, 2, 3 (default days)"
      puts "  rake topic:update_multiple[1,2,3,30]        # Update last 30 days"
      puts "  rake topic:update_multiple[1,2,3,60]        # Update last 60 days (full PDF range)"
      exit 1
    end
    
    ids = topic_ids.split(',').map(&:strip)
    
    puts "\n" + "=" * 80
    puts "🚀 BATCH UPDATE: #{ids.count} topics"
    puts "=" * 80
    
    batch_start = Time.current
    
    ids.each_with_index do |topic_id, index|
      puts "\n[#{index + 1}/#{ids.count}] Processing Topic ##{topic_id}..."
      
      begin
        Rake::Task['topic:update'].reenable
        Rake::Task['topic:update'].invoke(topic_id, days)
      rescue StandardError => e
        puts "❌ Topic ##{topic_id} failed: #{e.message}"
        next
      end
    end
    
    batch_duration = (Time.current - batch_start).round(2)
    
    puts "\n" + "=" * 80
    puts "🎉 BATCH UPDATE COMPLETE!"
    puts "   Topics updated: #{ids.count}"
    puts "   Total duration: #{batch_duration} seconds (#{(batch_duration / 60).round(2)} minutes)"
    puts "=" * 80
  end
  
  # ============================================
  # HELPER TASK: UPDATE ALL ACTIVE TOPICS
  # ============================================
  
  desc 'Update all active topics'
  task :update_all, [:days] => :environment do |_t, args|
    days = args[:days] || DAYS_RANGE
    
    active_topics = Topic.where(status: true)
    
    puts "\n" + "=" * 80
    puts "🚀 UPDATING ALL ACTIVE TOPICS"
    puts "=" * 80
    puts "   Total topics: #{active_topics.count}"
    puts "   Date range: Last #{days} days"
    puts "   ⚠️  Note: For PDF reports with 60-day range, use days=60"
    puts "=" * 80
    
    batch_start = Time.current
    
    active_topics.each_with_index do |topic, index|
      puts "\n[#{index + 1}/#{active_topics.count}] Processing: #{topic.name}..."
      
      begin
        Rake::Task['topic:update'].reenable
        Rake::Task['topic:update'].invoke(topic.id, days)
      rescue StandardError => e
        puts "❌ Topic '#{topic.name}' failed: #{e.message}"
        next
      end
    end
    
    batch_duration = (Time.current - batch_start).round(2)
    
    puts "\n" + "=" * 80
    puts "🎉 ALL TOPICS UPDATED!"
    puts "   Topics processed: #{active_topics.count}"
    puts "   Total duration: #{batch_duration} seconds (#{(batch_duration / 60).round(2)} minutes)"
    puts "=" * 80
  end
end


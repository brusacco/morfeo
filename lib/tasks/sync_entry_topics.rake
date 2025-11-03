# frozen_string_literal: true

namespace :entries do
  desc 'Sync all entries with their topics based on tags (populate entry_topics table)'
  task sync_topics: :environment do
    puts "🔄 Starting Entry-Topic synchronization..."
    puts "=" * 80
    
    start_time = Time.current
    total_entries = 0
    synced_entries = 0
    failed_entries = 0
    DAYS_RANGE = 60
    
    # Process entries in batches for better memory usage
    Entry.enabled.where(published_at: DAYS_RANGE.days.ago..Time.current).find_in_batches(batch_size: 500) do |batch|
      batch.each do |entry|
        total_entries += 1
        
        begin
          # Get current tag list
          tags = entry.tag_list
          
          if tags.empty?
            puts "⏭️  Entry #{entry.id}: No tags, skipping"
            next
          end
          
          # Find matching topics
          matching_topics = Topic.joins(:tags)
                                .where(tags: { name: tags })
                                .distinct
          
          # Sync the association
          entry.topics = matching_topics
          
          synced_entries += 1
          puts "✅ Entry #{entry.id}: Synced with #{matching_topics.count} topics - Tags: #{tags.join(', ')}"
          
        rescue => e
          failed_entries += 1
          puts "❌ Entry #{entry.id}: Failed - #{e.message}"
        end
        
        # Progress indicator every 100 entries
        if total_entries % 100 == 0
          puts "\n📊 Progress: #{total_entries} entries processed, #{synced_entries} synced, #{failed_entries} failed\n"
        end
      end
    end
    
    duration = (Time.current - start_time).round(2)
    
    puts "\n" + "=" * 80
    puts "✨ Synchronization Complete!"
    puts "=" * 80
    puts "📈 Statistics:"
    puts "   Total entries processed: #{total_entries}"
    puts "   Successfully synced: #{synced_entries}"
    puts "   Failed: #{failed_entries}"
    puts "   Duration: #{duration} seconds"
    puts "   Average: #{(duration / total_entries).round(3)} sec/entry" if total_entries > 0
    puts "=" * 80
    
    # Clear relevant caches
    puts "\n🧹 Clearing topic caches..."
    Rails.cache.delete_matched("topic_*_list_entries*")
    Rails.cache.delete_matched("digital_dashboard_*")
    puts "✅ Caches cleared"
    
    puts "\n🎯 Next steps:"
    puts "1. Verify USE_DIRECT_ENTRY_TOPICS=true in production .env"
    puts "2. Run: RAILS_ENV=production rails cache:warm_dashboards"
    puts "3. Check topic dashboards to verify entries are displaying"
  end
  
  desc 'Sync title tags for all entries (populate entry_title_topics table)'
  task sync_title_topics: :environment do
    puts "🔄 Starting Entry-Title-Topic synchronization..."
    puts "=" * 80
    
    start_time = Time.current
    total_entries = 0
    synced_entries = 0
    
    Entry.enabled.where(published_at: DAYS_RANGE.days.ago..Time.current).find_in_batches(batch_size: 500) do |batch|
      batch.each do |entry|
        total_entries += 1
        
        begin
          title_tags = entry.title_tag_list
          
          if title_tags.empty?
            next
          end
          
          matching_topics = Topic.joins(:tags)
                                .where(tags: { name: title_tags })
                                .distinct
          
          entry.title_topics = matching_topics
          synced_entries += 1
          
          puts "✅ Entry #{entry.id}: Synced title topics (#{matching_topics.count})"
          
        rescue => e
          puts "❌ Entry #{entry.id}: Failed - #{e.message}"
        end
      end
    end
    
    duration = (Time.current - start_time).round(2)
    
    puts "\n" + "=" * 80
    puts "✨ Title Topic Synchronization Complete!"
    puts "   Total: #{total_entries}, Synced: #{synced_entries}"
    puts "   Duration: #{duration} seconds"
    puts "=" * 80
  end
  
  desc 'Sync a specific entry by ID'
  task :sync_entry, [:entry_id] => :environment do |_t, args|
    entry_id = args[:entry_id]
    
    unless entry_id
      puts "❌ Error: Please provide an entry ID"
      puts "Usage: rake entries:sync_entry[123]"
      exit 1
    end
    
    entry = Entry.find(entry_id)
    
    puts "🔄 Syncing Entry ##{entry.id}"
    puts "   URL: #{entry.url}"
    puts "   Tags: #{entry.tag_list.join(', ')}"
    
    # Regular tags
    if entry.tag_list.any?
      matching_topics = Topic.joins(:tags)
                            .where(tags: { name: entry.tag_list })
                            .distinct
      
      entry.topics = matching_topics
      puts "   ✅ Synced with #{matching_topics.count} topics (regular tags)"
      puts "   Topics: #{matching_topics.pluck(:name).join(', ')}"
    else
      puts "   ⏭️  No regular tags"
    end
    
    # Title tags
    if entry.title_tag_list.any?
      matching_topics = Topic.joins(:tags)
                            .where(tags: { name: entry.title_tag_list })
                            .distinct
      
      entry.title_topics = matching_topics
      puts "   ✅ Synced with #{matching_topics.count} topics (title tags)"
    else
      puts "   ⏭️  No title tags"
    end
    
    puts "\n✅ Entry synchronized successfully!"
  rescue ActiveRecord::RecordNotFound
    puts "❌ Error: Entry ##{entry_id} not found"
    exit 1
  rescue => e
    puts "❌ Error: #{e.message}"
    puts e.backtrace.first(5).join("\n")
    exit 1
  end
  
  desc 'Check sync status for a specific topic'
  task :check_topic_sync, [:topic_id] => :environment do |_t, args|
    topic_id = args[:topic_id]
    
    unless topic_id
      puts "❌ Error: Please provide a topic ID"
      puts "Usage: rake entries:check_topic_sync[9]"
      exit 1
    end
    
    topic = Topic.find(topic_id)
    
    puts "🔍 Checking sync status for Topic: #{topic.name}"
    puts "=" * 80
    
    tag_names = topic.tags.pluck(:name)
    puts "📌 Topic Tags: #{tag_names.join(', ')}"
    
    # Count entries via taggings (acts_as_taggable_on)
    tagged_entries = Entry.enabled
                          .where(published_at: DAYS_RANGE.days.ago..Time.current)
                          .tagged_with(tag_names, any: true)
                          .count
    
    # Count entries via entry_topics (direct association)
    synced_entries = topic.entries
                          .enabled
                          .where(published_at: DAYS_RANGE.days.ago..Time.current)
                          .count
    
    puts "\n📊 Entry Counts:"
    puts "   Via tags (taggings table): #{tagged_entries} entries"
    puts "   Via topics (entry_topics): #{synced_entries} entries"
    
    difference = tagged_entries - synced_entries
    
    if difference > 0
      puts "\n⚠️  MISMATCH DETECTED!"
      puts "   #{difference} entries are tagged but NOT synced to entry_topics"
      puts "   This is why they don't appear in the topic dashboard"
      puts "\n🔧 Solution: Run 'rake entries:sync_topics' to fix this"
    elsif difference < 0
      puts "\n⚠️  WARNING: More synced entries than tagged entries (data inconsistency)"
    else
      puts "\n✅ Perfect sync! All tagged entries are properly associated"
    end
    
    puts "=" * 80
    
  rescue ActiveRecord::RecordNotFound
    puts "❌ Error: Topic ##{topic_id} not found"
    exit 1
  end
end


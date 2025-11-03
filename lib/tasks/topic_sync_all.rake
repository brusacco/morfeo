# frozen_string_literal: true

namespace :topic do
  desc 'Sync entry_topics associations for all active topics (lightweight alternative to topic:update_all)'
  task :sync_all, [:days] => :environment do |_t, args|
    days = args[:days].presence ? Integer(args[:days]) : 60
    start_date = days.days.ago.beginning_of_day
    end_date = Time.current.end_of_day
    
    puts "=" * 80
    puts "🔄 SYNC ALL TOPICS"
    puts "=" * 80
    puts "Days Range: #{days} days"
    puts "Start Date: #{start_date.strftime('%Y-%m-%d')}"
    puts "End Date: #{end_date.strftime('%Y-%m-%d')}"
    puts "=" * 80
    puts

    topics = Topic.where(status: true).order(:name)
    
    if topics.empty?
      puts "⚠️  No active topics found"
      exit 0
    end

    puts "Topics to sync: #{topics.count}"
    puts

    successful = 0
    failed = 0
    total_entries_synced = 0
    start_time = Time.current

    topics.each_with_index do |topic, index|
      begin
        print "\r[#{index + 1}/#{topics.count}] Processing #{topic.name}...".ljust(80)
        
        tag_names = topic.tags.pluck(:name)
        
        if tag_names.empty?
          puts "\r[#{index + 1}/#{topics.count}] ⚠️  #{topic.name} - No tags, skipped".ljust(80)
          next
        end
        
        # Find matching entries using acts_as_taggable_on (ground truth)
        entries = Entry.enabled
                      .where(published_at: start_date..end_date)
                      .tagged_with(tag_names, any: true)
                      .distinct
        
        entries_count = entries.count('DISTINCT entries.id')
        
        if entries_count.zero?
          puts "\r[#{index + 1}/#{topics.count}] ✓ #{topic.name} - No entries in range".ljust(80)
          successful += 1
          next
        end
        
        # Sync each entry (will use the entry's sync_topics_from_tags method)
        synced = 0
        entries.find_each do |entry|
          entry.sync_topics_from_tags
          synced += 1
        end
        
        total_entries_synced += synced
        successful += 1
        
        puts "\r[#{index + 1}/#{topics.count}] ✅ #{topic.name} - Synced #{synced} entries".ljust(80)
        
      rescue => e
        failed += 1
        puts "\r[#{index + 1}/#{topics.count}] ❌ #{topic.name} - ERROR: #{e.message}".ljust(80)
        puts "   Backtrace: #{e.backtrace.first(2).join("\n   ")}" if ENV['DEBUG']
      end
    end

    duration = Time.current - start_time
    
    puts
    puts "=" * 80
    puts "📊 SYNC SUMMARY"
    puts "=" * 80
    puts "Total Topics: #{topics.count}"
    puts "✅ Successful: #{successful}"
    puts "❌ Failed: #{failed}" if failed > 0
    puts "📝 Total Entries Synced: #{total_entries_synced}"
    puts "⏱️  Duration: #{duration.round(2)}s"
    puts "📈 Rate: #{(total_entries_synced / duration).round(2)} entries/sec"
    puts "=" * 80
    puts
    
    if successful == topics.count
      puts "🎉 All topics synced successfully!"
    else
      puts "⚠️  Some topics failed. Check output above for details."
    end
    puts
  end

  desc 'Sync entry_topics for a single topic (lightweight alternative to topic:update)'
  task :sync, [:topic_id, :days] => :environment do |_t, args|
    unless args[:topic_id]
      puts "❌ Error: TOPIC_ID is required"
      puts "Usage: rake 'topic:sync[TOPIC_ID,DAYS]'"
      puts "Example: rake 'topic:sync[32,60]'"
      exit 1
    end

    topic_id = Integer(args[:topic_id])
    days = args[:days].presence ? Integer(args[:days]) : 60
    
    topic = Topic.find_by(id: topic_id)
    
    unless topic
      puts "❌ Error: Topic with ID #{topic_id} not found"
      exit 1
    end

    puts "=" * 80
    puts "🔄 SYNC TOPIC"
    puts "=" * 80
    puts "Topic ID: #{topic.id}"
    puts "Topic Name: #{topic.name}"
    puts "Days Range: #{days} days"
    puts "=" * 80
    puts

    tag_names = topic.tags.pluck(:name)
    
    if tag_names.empty?
      puts "⚠️  Topic has no tags - nothing to sync"
      exit 0
    end

    puts "Tags: #{tag_names.join(', ')}"
    puts

    start_date = days.days.ago.beginning_of_day
    end_date = Time.current.end_of_day
    start_time = Time.current

    # Find matching entries
    entries = Entry.enabled
                  .where(published_at: start_date..end_date)
                  .tagged_with(tag_names, any: true)
                  .distinct

    entries_count = entries.count('DISTINCT entries.id')

    puts "Found #{entries_count} entries to sync"
    puts

    if entries_count.zero?
      puts "✓ No entries found in date range"
      exit 0
    end

    # Sync each entry
    synced = 0
    entries.find_each.with_index do |entry, index|
      entry.sync_topics_from_tags
      synced += 1
      
      if (index + 1) % 50 == 0
        print "\rSynced #{index + 1}/#{entries_count}..."
      end
    end

    duration = Time.current - start_time

    puts "\r✅ Synced #{synced}/#{entries_count} entries".ljust(50)
    puts
    puts "=" * 80
    puts "📊 SYNC COMPLETE"
    puts "=" * 80
    puts "Entries Synced: #{synced}"
    puts "Duration: #{duration.round(2)}s"
    puts "Rate: #{(synced / duration).round(2)} entries/sec"
    puts "=" * 80
    puts
  end
end


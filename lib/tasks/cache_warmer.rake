# frozen_string_literal: true

namespace :cache do
  desc 'Warm up cache for Topics and Tags - preload entries for fast page loads'
  task warm: :environment do
    puts "🔥 Starting cache warming at #{Time.current}"
    
    start_time = Time.current
    
    # Warm up Topic caches
    topics_warmed = 0
    Topic.active.find_each do |topic|
      begin
        # Warm up main entries cache
        topic.list_entries
        
        # Warm up title entries cache if needed
        topic.title_list_entries if topic.respond_to?(:title_list_entries)
        
        topics_warmed += 1
        print "."
      rescue => e
        puts "\n⚠️  Error warming Topic #{topic.id} (#{topic.name}): #{e.message}"
      end
    end
    
    puts "\n✅ Warmed #{topics_warmed} topics"
    
    # Warm up Tag caches
    tags_warmed = 0
    
    # Only warm frequently used tags (those belonging to active topics)
    active_tags = Tag.joins(:topics)
                     .where(topics: { status: true })
                     .distinct
    
    active_tags.find_each do |tag|
      begin
        # Warm up main entries cache
        tag.list_entries
        
        # Warm up title entries cache
        tag.title_list_entries
        
        tags_warmed += 1
        print "."
      rescue => e
        puts "\n⚠️  Error warming Tag #{tag.id} (#{tag.name}): #{e.message}"
      end
    end
    
    puts "\n✅ Warmed #{tags_warmed} tags"
    
    duration = (Time.current - start_time).round(2)
    puts "⏱️  Cache warming completed in #{duration} seconds"
    puts "🎯 Topics: #{topics_warmed} | Tags: #{tags_warmed}"
  end
  
  desc 'Warm cache for a specific topic by ID'
  task :warm_topic, [:topic_id] => :environment do |_t, args|
    topic = Topic.find(args[:topic_id])
    puts "🔥 Warming cache for Topic: #{topic.name}"
    
    topic.list_entries
    topic.title_list_entries if topic.respond_to?(:title_list_entries)
    
    puts "✅ Cache warmed for #{topic.name}"
  end
  
  desc 'Warm cache for a specific tag by ID'
  task :warm_tag, [:tag_id] => :environment do |_t, args|
    tag = Tag.find(args[:tag_id])
    puts "🔥 Warming cache for Tag: #{tag.name}"
    
    tag.list_entries
    tag.title_list_entries
    
    puts "✅ Cache warmed for #{tag.name}"
  end
  
  desc 'Clear all topic and tag caches'
  task clear: :environment do
    puts "🧹 Clearing topic and tag caches..."
    
    Rails.cache.delete_matched("topic_*")
    Rails.cache.delete_matched("tag_*")
    
    puts "✅ Cache cleared"
  end
  
  desc 'Clear and re-warm all caches'
  task refresh: :environment do
    puts "♻️  Refreshing all caches..."
    
    Rake::Task['cache:clear'].invoke
    Rake::Task['cache:warm'].invoke
    
    puts "✅ Cache refresh complete"
  end
end


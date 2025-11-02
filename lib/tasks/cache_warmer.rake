# frozen_string_literal: true

namespace :cache do
  desc 'Warm up cache for Topics and Tags - preload entries for fast page loads'
  task warm: :environment do
    puts "🔥 Starting cache warming at #{Time.current}"
    
    start_time = Time.current
    
    # Warm up Topic caches
    topics_warmed = 0
    dashboards_warmed = 0
    
    Topic.active.find_each do |topic|
      begin
        # 1. Warm up main entries cache
        topic.list_entries
        
        # 2. Warm up title entries cache if needed
        topic.title_list_entries if topic.respond_to?(:title_list_entries)
        
        # 3. Warm up Digital Dashboard Service Cache
        DigitalDashboardServices::AggregatorService.call(topic: topic)
        
        # 4. Warm up Facebook Dashboard Service Cache
        FacebookDashboardServices::AggregatorService.call(topic: topic, top_posts_limit: 20)
        
        # 5. Warm up Twitter Dashboard Service Cache
        TwitterDashboardServices::AggregatorService.call(topic: topic, top_posts_limit: 20)
        
        # 6. Warm up General Dashboard Service Cache (CEO reporting)
        GeneralDashboardServices::AggregatorService.call(
          topic: topic,
          start_date: DAYS_RANGE.days.ago.beginning_of_day,
          end_date: Time.zone.now.end_of_day
        )
        
        topics_warmed += 1
        dashboards_warmed += 4 # Digital + Facebook + Twitter + General
        print "."
      rescue => e
        puts "\n⚠️  Error warming Topic #{topic.id} (#{topic.name}): #{e.message}"
      end
    end
    
    puts "\n✅ Warmed #{topics_warmed} topics (#{dashboards_warmed} dashboards)"
    
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
    minutes = (duration / 60).floor
    seconds = (duration % 60).round(2)
    
    puts "\n⏱️  Cache warming completed in #{minutes > 0 ? "#{minutes}m " : ""}#{seconds}s"
    puts "🎯 Summary:"
    puts "   Topics: #{topics_warmed}"
    puts "   Dashboards: #{dashboards_warmed}"
    puts "   Tags: #{tags_warmed}"
    puts "   Total items cached: #{topics_warmed + dashboards_warmed + tags_warmed}"
  end
  
  desc 'Warm cache for a specific topic by ID'
  task :warm_topic, [:topic_id] => :environment do |_t, args|
    topic = Topic.find(args[:topic_id])
    puts "🔥 Warming cache for Topic: #{topic.name}"
    
    start_time = Time.current
    
    # Basic entries cache
    topic.list_entries
    topic.title_list_entries if topic.respond_to?(:title_list_entries)
    
    # Dashboard service caches
    puts "  📊 Warming Digital Dashboard..."
    DigitalDashboardServices::AggregatorService.call(topic: topic)
    
    puts "  📘 Warming Facebook Dashboard..."
    FacebookDashboardServices::AggregatorService.call(topic: topic, top_posts_limit: 20)
    
    puts "  🐦 Warming Twitter Dashboard..."
    TwitterDashboardServices::AggregatorService.call(topic: topic, top_posts_limit: 20)
    
    puts "  📈 Warming General Dashboard..."
    GeneralDashboardServices::AggregatorService.call(
      topic: topic,
      start_date: DAYS_RANGE.days.ago.beginning_of_day,
      end_date: Time.zone.now.end_of_day
    )
    
    duration = (Time.current - start_time).round(2)
    puts "✅ Cache warmed for #{topic.name} in #{duration}s"
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
    puts "🧹 Clearing all caches..."
    
    # Clear topic and tag entry caches
    Rails.cache.delete_matched("topic_*")
    Rails.cache.delete_matched("tag_*")
    
    # Clear dashboard service caches
    Rails.cache.delete_matched("digital_dashboard_*")
    Rails.cache.delete_matched("facebook_dashboard_*")
    Rails.cache.delete_matched("twitter_dashboard_*")
    Rails.cache.delete_matched("general_dashboard_*")
    Rails.cache.delete_matched("home_dashboard_*")
    
    # Clear action caches (views)
    Rails.cache.delete_matched("views/*")
    
    puts "✅ All caches cleared"
  end
  
  desc 'Clear and re-warm all caches'
  task refresh: :environment do
    puts "♻️  Refreshing all caches..."
    
    Rake::Task['cache:clear'].invoke
    Rake::Task['cache:warm'].invoke
    
    puts "✅ Cache refresh complete"
  end
  
  desc 'Warm only dashboard caches (faster)'
  task warm_dashboards: :environment do
    puts "🔥 Warming dashboard caches for all active topics..."
    
    start_time = Time.current
    topics_warmed = 0
    
    Topic.active.find_each do |topic|
      begin
        puts "\n📊 Topic: #{topic.name}"
        
        # Digital Dashboard
        print "  Digital..."
        DigitalDashboardServices::AggregatorService.call(topic: topic)
        print " ✓"
        
        # Facebook Dashboard
        print " Facebook..."
        FacebookDashboardServices::AggregatorService.call(topic: topic, top_posts_limit: 20)
        print " ✓"
        
        # Twitter Dashboard
        print " Twitter..."
        TwitterDashboardServices::AggregatorService.call(topic: topic, top_posts_limit: 20)
        print " ✓"
        
        # General Dashboard
        print " General..."
        GeneralDashboardServices::AggregatorService.call(
          topic: topic,
          start_date: DAYS_RANGE.days.ago.beginning_of_day,
          end_date: Time.zone.now.end_of_day
        )
        print " ✓"
        
        topics_warmed += 1
      rescue => e
        puts "\n⚠️  Error: #{e.message}"
      end
    end
    
    duration = (Time.current - start_time).round(2)
    minutes = (duration / 60).floor
    seconds = (duration % 60).round(2)
    
    puts "\n\n✅ Dashboard warming complete!"
    puts "⏱️  Time: #{minutes > 0 ? "#{minutes}m " : ""}#{seconds}s"
    puts "📊 Topics: #{topics_warmed} (#{topics_warmed * 4} dashboards)"
  end
end


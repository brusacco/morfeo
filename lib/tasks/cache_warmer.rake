# frozen_string_literal: true

require 'parallel'

namespace :cache do
  desc 'Warm up cache for Topics and Tags - preload entries for fast page loads'
  task warm: :environment do
    puts "🔥 Starting cache warming at #{Time.current}"

    start_time = Time.current

    # Warm up Topic caches IN PARALLEL
    topics = Topic.active.to_a
    puts "📊 Warming #{topics.count} topics in parallel..."

    results =
      Parallel.map(topics, in_processes: 4, progress: 'Warming topics') do |topic|
        ActiveRecord::Base.connection.reconnect! # Reconnect in each process

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

          # 6. Warm up Instagram Dashboard Service Cache
          InstagramDashboardServices::AggregatorService.call(topic: topic, top_posts_limit: 20)

          # 7. Warm up General Dashboard Service Cache (CEO reporting)
          GeneralDashboardServices::AggregatorService.call(
            topic: topic,
            start_date: DAYS_RANGE.days.ago.beginning_of_day,
            end_date: Time.zone.now.end_of_day
          )

          { success: true, topic_id: topic.id, topic_name: topic.name, dashboards: 5 }
        rescue StandardError => e
          { success: false, topic_id: topic.id, topic_name: topic.name, error: e.message }
        end
      end

    # Count results
    successful = results.select { |r| r[:success] }
    failed = results.reject { |r| r[:success] }

    puts "\n✅ Warmed #{successful.count} topics (#{successful.count * 5} dashboards)"

    if failed.any?
      puts "\n⚠️  #{failed.count} topics failed:"
      failed.each do |f|
        puts "   - Topic #{f[:topic_id]} (#{f[:topic_name]}): #{f[:error]}"
      end
    end

    # Warm up Tag caches IN PARALLEL
    active_tags = Tag.joins(:topics).where(topics: { status: true }).distinct.to_a

    puts "\n🏷️  Warming #{active_tags.count} tags in parallel..."

    tag_results =
      Parallel.map(active_tags, in_processes: 4, progress: 'Warming tags') do |tag|
        ActiveRecord::Base.connection.reconnect! # Reconnect in each process

        begin
          tag.list_entries
          tag.title_list_entries
          { success: true, tag_id: tag.id, tag_name: tag.name }
        rescue StandardError => e
          { success: false, tag_id: tag.id, tag_name: tag.name, error: e.message }
        end
      end

    tags_successful = tag_results.select { |r| r[:success] }
    tags_failed = tag_results.reject { |r| r[:success] }

    puts "\n✅ Warmed #{tags_successful.count} tags"

    if tags_failed.any?
      puts "\n⚠️  #{tags_failed.count} tags failed:"
      tags_failed.each do |f|
        puts "   - Tag #{f[:tag_id]} (#{f[:tag_name]}): #{f[:error]}"
      end
    end

    duration = (Time.current - start_time).round(2)
    minutes = (duration / 60).floor
    seconds = (duration % 60).round(2)

    puts "\n⏱️  Cache warming completed in #{"#{minutes}m " if minutes > 0}#{seconds}s"
    puts '🎯 Summary:'
    puts "   Topics: #{successful.count} successful, #{failed.count} failed"
    puts "   Dashboards: #{successful.count * 5}"
    puts "   Tags: #{tags_successful.count} successful, #{tags_failed.count} failed"
    puts "   Total items cached: #{successful.count + (successful.count * 5) + tags_successful.count}"
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
    puts '  📊 Warming Digital Dashboard...'
    DigitalDashboardServices::AggregatorService.call(topic: topic)

    puts '  📘 Warming Facebook Dashboard...'
    FacebookDashboardServices::AggregatorService.call(topic: topic, top_posts_limit: 20)

    puts '  🐦 Warming Twitter Dashboard...'
    TwitterDashboardServices::AggregatorService.call(topic: topic, top_posts_limit: 20)

    puts '  📸 Warming Instagram Dashboard...'
    InstagramDashboardServices::AggregatorService.call(topic: topic, top_posts_limit: 20)

    puts '  📈 Warming General Dashboard...'
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
    puts '🧹 Clearing all caches...'

    # Clear topic and tag entry caches
    Rails.cache.delete_matched('topic_*')
    Rails.cache.delete_matched('tag_*')

    # Clear dashboard service caches
    Rails.cache.delete_matched('digital_dashboard:v3:*')
    Rails.cache.delete_matched('facebook_dashboard:v3:*')
    Rails.cache.delete_matched('twitter_dashboard:v3:*')
    Rails.cache.delete_matched('instagram_dashboard:v3:*')
    Rails.cache.delete_matched('general_dashboard:v3:*')
    Rails.cache.delete_matched('home_dashboard:v3:*')
    Rails.cache.delete_matched('home_dashboard:v4:*')

    # Clear action caches (views)
    Rails.cache.delete_matched('views/*')

    puts '✅ All caches cleared'
  end

  desc 'Clear and re-warm all caches'
  task refresh: :environment do
    puts '♻️  Refreshing all caches...'

    Rake::Task['cache:clear'].invoke
    Rake::Task['cache:warm'].invoke

    puts '✅ Cache refresh complete'
  end

  desc 'Warm only dashboard caches (faster) - PARALLEL'
  task warm_dashboards: :environment do
    puts '🔥 Warming dashboard caches for all active topics IN PARALLEL...'

    start_time = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    topic_ids = Topic.active.pluck(:id)
    workers = ENV.fetch('CACHE_WARM_WORKERS', 4).to_i
    workers = CacheWarmDashboardReporter.worker_count(workers)

    puts "📊 Processing #{topic_ids.count} topics with #{workers} parallel workers..."

    results =
      Parallel.map(topic_ids, in_processes: workers, progress: 'Dashboards') do |topic_id|
        started_at = Process.clock_gettime(Process::CLOCK_MONOTONIC)

        begin
          ActiveRecord::Base.connection.reconnect!
          topic = Topic.find(topic_id)
          CacheWarmDashboardReporter.new.warm_topic(topic)
        rescue StandardError => e
          {
            success: false,
            topic_id: topic_id,
            topic_name: nil,
            duration: Process.clock_gettime(Process::CLOCK_MONOTONIC) - started_at,
            dashboards: {},
            error_class: e.class.name,
            error: e.message,
            backtrace: ENV['CACHE_WARM_DEBUG'] == '1' ? e.backtrace&.first(5) : nil
          }
        end
      end

    successful = results.select { |r| r[:success] }
    failed = results.reject { |r| r[:success] }

    duration = Process.clock_gettime(Process::CLOCK_MONOTONIC) - start_time

    puts "\n\n✅ Dashboard warming complete!"
    puts "📊 Topics: #{successful.count} successful, #{failed.count} failed"

    if failed.any?
      puts "\n⚠️  #{failed.count} topics failed:"
      failed.each do |f|
        puts "   - Topic #{f[:topic_id]} (#{f[:topic_name] || 'unknown'}): #{f[:error_class]}: #{f[:error]}"
        Array(f[:backtrace]).each { |line| puts "     #{line}" }
      end
    end

    CacheWarmDashboardReporter.new.print_report(results: results, workers: workers, wall_time: duration)
  end
end

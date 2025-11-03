# frozen_string_literal: true

namespace :audit do
  desc 'Check entry_topics sync health for all topics and alert if issues found'
  task sync_health: :environment do
    puts "=" * 80
    puts "🏥 SYNC HEALTH CHECK"
    puts "=" * 80
    puts "Time: #{Time.current.strftime('%Y-%m-%d %H:%M:%S')}"
    puts "=" * 80
    puts

    issues = []
    healthy_topics = []
    
    periods = [
      { days: 7, label: '7 days', threshold: 5 },
      { days: 30, label: '30 days', threshold: 10 },
      { days: 60, label: '60 days', threshold: 15 }
    ]

    Topic.where(status: true).order(:name).each do |topic|
      tag_names = topic.tags.pluck(:name)
      
      if tag_names.empty?
        next # Skip topics without tags
      end

      topic_issues = []

      periods.each do |period|
        start_date = period[:days].days.ago.beginning_of_day
        end_date = Time.current.end_of_day

        # Method 1: Direct tag query (ground truth)
        direct_count = Entry.enabled
                            .where(published_at: start_date..end_date)
                            .tagged_with(tag_names, any: true)
                            .distinct
                            .count('DISTINCT entries.id')

        # Method 2: Association query (what PDFs use)
        assoc_count = topic.entries
                          .enabled
                          .where(published_at: start_date..end_date)
                          .count

        diff = direct_count - assoc_count

        if diff.abs > period[:threshold]
          topic_issues << {
            period: period[:label],
            direct: direct_count,
            association: assoc_count,
            difference: diff,
            percentage: direct_count > 0 ? ((Float(diff.abs) / direct_count) * 100).round(1) : 0
          }
        end
      end

      if topic_issues.any?
        issues << {
          topic_id: topic.id,
          topic_name: topic.name,
          tag_count: tag_names.size,
          issues: topic_issues
        }
      else
        healthy_topics << topic.name
      end
    end

    # Report results
    if issues.empty?
      puts "✅ ALL TOPICS HEALTHY"
      puts
      puts "All #{healthy_topics.size} active topics are properly synced"
      puts "=" * 80
    else
      puts "⚠️  SYNC ISSUES DETECTED"
      puts "=" * 80
      puts
      
      issues.each do |topic_issue|
        puts "❌ Topic #{topic_issue[:topic_id]}: #{topic_issue[:topic_name]} (#{topic_issue[:tag_count]} tags)"
        puts "-" * 80
        
        topic_issue[:issues].each do |issue|
          status_icon = issue[:difference] > 0 ? "📉" : "📈"
          puts "  #{status_icon} #{issue[:period]}:"
          puts "     Direct (tags):    #{issue[:direct]}"
          puts "     Association:      #{issue[:association]}"
          puts "     Difference:       #{issue[:difference]} (#{issue[:percentage]}%)"
        end
        puts
      end

      puts "=" * 80
      puts "📊 SUMMARY"
      puts "=" * 80
      puts "Healthy Topics: #{healthy_topics.size}"
      puts "Issues Found: #{issues.size}"
      puts
      puts "🔧 RECOMMENDED ACTIONS:"
      puts "=" * 80
      
      issues.each do |issue|
        # Determine which period has the biggest issue
        worst_issue = issue[:issues].max_by { |i| i[:percentage] }
        days_needed = case worst_issue[:period]
                      when '7 days' then 7
                      when '30 days' then 30
                      when '60 days' then 60
                      else 60
                      end
        
        puts "  Topic #{issue[:topic_id]} (#{issue[:topic_name]}):"
        puts "    └─ Run: rake 'topic:sync[#{issue[:topic_id]},#{days_needed}]'"
      end
      
      puts
      puts "  Or sync all at once:"
      puts "    └─ rake 'topic:sync_all[60]'"
      puts
      
      # Log to file for monitoring
      log_file = Rails.root.join('log', 'sync_health.log')
      File.open(log_file, 'a') do |f|
        f.puts "[#{Time.current}] ISSUES FOUND: #{issues.size} topics out of sync"
        issues.each do |issue|
          f.puts "  - Topic #{issue[:topic_id]} (#{issue[:topic_name]}): #{issue[:issues].map { |i| i[:period] }.join(', ')}"
        end
      end
      
      puts "📝 Issues logged to: #{log_file}"
      puts
    end

    puts "=" * 80
    puts "✅ Health check complete"
    puts
    
    # Return status code
    exit(issues.any? ? 1 : 0)
  end

  desc 'Quick sync health check for a single topic'
  task :sync_health_topic, [:topic_id] => :environment do |_t, args|
    if args[:topic_id].blank?
      puts "❌ Error: TOPIC_ID is required"
      puts "Usage: rake 'audit:sync_health_topic[TOPIC_ID]'"
      exit 1
    end

    topic_id = Integer(args[:topic_id])
    topic = Topic.find_by(id: topic_id)

    if topic.nil?
      puts "❌ Error: Topic with ID #{topic_id} not found"
      exit 1
    end

    puts "=" * 80
    puts "🏥 TOPIC SYNC HEALTH"
    puts "=" * 80
    puts "Topic: #{topic.name} (ID: #{topic.id})"
    puts "Time: #{Time.current.strftime('%Y-%m-%d %H:%M:%S')}"
    puts "=" * 80
    puts

    tag_names = topic.tags.pluck(:name)

    if tag_names.empty?
      puts "⚠️  Topic has no tags"
      exit 0
    end

    puts "Tags: #{tag_names.join(', ')}"
    puts

    all_healthy = true

    [7, 15, 30, 60].each do |days|
      start_date = days.days.ago.beginning_of_day
      end_date = Time.current.end_of_day

      direct = Entry.enabled
                    .where(published_at: start_date..end_date)
                    .tagged_with(tag_names, any: true)
                    .distinct
                    .count('DISTINCT entries.id')

      assoc = topic.entries
                  .enabled
                  .where(published_at: start_date..end_date)
                  .count

      diff = direct - assoc
      status = diff.abs <= 5 ? "✅" : "⚠️ "

      if diff.abs > 5
        all_healthy = false
      end

      puts "#{status} #{days} days: Direct=#{direct}, Association=#{assoc}, Diff=#{diff}"
    end

    puts
    puts "=" * 80

    if all_healthy
      puts "✅ Topic is healthy!"
    else
      puts "⚠️  Topic needs syncing"
      puts
      puts "Fix with:"
      puts "  rake 'topic:sync[#{topic.id},60]'"
    end

    puts "=" * 80
    puts
  end
end


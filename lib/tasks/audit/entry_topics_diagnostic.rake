# frozen_string_literal: true

namespace :audit do
  namespace :entry_topics do
    desc 'Diagnose entry_topics table population for a topic'
    task :check, [:topic_id] => :environment do |_t, args|
      unless args[:topic_id]
        puts "❌ Error: TOPIC_ID is required"
        puts "Usage: rake 'audit:entry_topics:check[TOPIC_ID]'"
        exit 1
      end

      topic_id = args[:topic_id].to_i
      topic = Topic.find_by(id: topic_id)

      unless topic
        puts "❌ Error: Topic with ID #{topic_id} not found"
        exit 1
      end

      puts "=" * 80
      puts "🔍 ENTRY_TOPICS DIAGNOSTIC"
      puts "=" * 80
      puts "Topic ID: #{topic.id}"
      puts "Topic Name: #{topic.name}"
      puts "Tags: #{topic.tags.pluck(:name).join(', ')}"
      puts "Time: #{Time.current.strftime('%Y-%m-%d %H:%M:%S')}"
      puts "=" * 80
      puts

      tag_names = topic.tags.pluck(:name)

      periods = [
        { days: 7, label: 'Last 7 days' },
        { days: 15, label: 'Last 15 days' },
        { days: 30, label: 'Last 30 days' },
        { days: 60, label: 'Last 60 days' }
      ]

      periods.each do |period|
        puts "📅 #{period[:label].upcase}"
        puts "-" * 80

        start_date = period[:days].days.ago.beginning_of_day
        end_date = Time.current.end_of_day

        # Method 1: Using acts_as_taggable_on (DIRECT - always accurate)
        tagged_entries = Entry.enabled
                              .where(published_at: start_date..end_date)
                              .tagged_with(tag_names, any: true)
                              .distinct

        tagged_count = tagged_entries.count('DISTINCT entries.id')
        tagged_interactions = tagged_count > 0 ? tagged_entries.sum(:total_count) : 0

        # Method 2: Using entry_topics association (CACHED - may be outdated)
        association_entries = topic.entries
                                   .enabled
                                   .where(published_at: start_date..end_date)

        association_count = association_entries.count
        association_interactions = association_count > 0 ? association_entries.sum(:total_count) : 0

        puts "  🏷️  Via acts_as_taggable_on (DIRECT - always accurate):"
        puts "     Entries: #{tagged_count}"
        puts "     Interactions: #{tagged_interactions}"
        puts

        puts "  🔗 Via entry_topics association (CACHED - used by PDFs):"
        puts "     Entries: #{association_count}"
        puts "     Interactions: #{association_interactions}"
        puts

        # Compare
        difference = tagged_count - association_count
        missing_pct = tagged_count > 0 ? ((difference.to_f / tagged_count) * 100).round(1) : 0

        if difference.zero?
          puts "  ✅ STATUS: SYNCED - Both methods return same count"
        elsif difference > 0
          puts "  ⚠️  STATUS: OUT OF SYNC - Missing #{difference} entries (#{missing_pct}%)"
          puts "     └─ PDF reports will be INCOMPLETE"
          puts "     └─ Run: rake 'topic:update[#{topic_id},#{period[:days]}]'"
        else
          puts "  ⚠️  STATUS: OVER-SYNCED - Association has #{difference.abs} extra entries"
          puts "     └─ Old entries not cleaned up"
        end
        puts "=" * 80
        puts
      end

      # Summary
      puts "📊 RECOMMENDATIONS"
      puts "-" * 80
      
      # Check which period needs the most syncing
      max_sync_needed = 60
      start_date = max_sync_needed.days.ago.beginning_of_day
      end_date = Time.current.end_of_day
      
      tagged = Entry.enabled
                    .where(published_at: start_date..end_date)
                    .tagged_with(tag_names, any: true)
                    .distinct
                    .count('DISTINCT entries.id')
      
      cached = topic.entries.enabled.where(published_at: start_date..end_date).count
      
      if tagged > cached
        puts "⚠️  Your entry_topics table is OUT OF SYNC"
        puts
        puts "To fix PDF reports for ALL time periods, run:"
        puts "  └─ RAILS_ENV=production rake 'topic:update[#{topic_id},60]'"
        puts
        puts "This will:"
        puts "  ✅ Sync entries from the last 60 days into entry_topics"
        puts "  ✅ Update TopicStatDaily records"
        puts "  ✅ Fix PDF reports for all time ranges (7, 15, 30, 60 days)"
        puts "  ⏱️  Takes ~30-60 seconds per topic"
      else
        puts "✅ Your entry_topics table is UP TO DATE"
        puts "   PDF reports should work correctly for all time periods"
      end
      
      puts "=" * 80
      puts "✅ Diagnostic complete!"
      puts
    end
  end
end


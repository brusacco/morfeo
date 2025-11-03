# frozen_string_literal: true

namespace :topic do
  desc 'Update all topics that use a specific tag'
  task :update_by_tag, [:tag_id, :days] => :environment do |_t, args|
    unless args[:tag_id]
      puts "❌ Error: TAG_ID is required"
      puts "Usage: rake 'topic:update_by_tag[TAG_ID,DAYS]'"
      puts "Example: rake 'topic:update_by_tag[248,60]'"
      exit 1
    end

    tag_id = Integer(args[:tag_id])
    days = args[:days].presence ? Integer(args[:days]) : 60
    
    tag = ActsAsTaggableOn::Tag.find_by(id: tag_id)
    
    unless tag
      puts "❌ Error: Tag with ID #{tag_id} not found"
      exit 1
    end

    # Find all topics using this tag
    topics = Topic.joins(:tags).where('tags.id = ?', tag_id).order(:name)
    
    if topics.empty?
      puts "⚠️  Warning: No topics found using tag '#{tag.name}' (ID: #{tag_id})"
      puts "This tag exists but is not assigned to any topics."
      exit 0
    end

    puts "=" * 80
    puts "🔄 UPDATE TOPICS BY TAG"
    puts "=" * 80
    puts "Tag ID: #{tag.id}"
    puts "Tag Name: #{tag.name}"
    puts "Days Range: #{days} days"
    puts "Topics Found: #{topics.count}"
    puts "=" * 80
    puts

    # List topics
    puts "📋 Topics to update:"
    topics.each do |topic|
      puts "  - [#{topic.id}] #{topic.name}"
    end
    puts

    # Confirm
    print "Continue with update? (y/N): "
    confirmation = STDIN.gets.chomp.downcase
    
    unless confirmation == 'y' || confirmation == 'yes'
      puts "❌ Update cancelled"
      exit 0
    end
    
    puts
    puts "=" * 80
    puts "🚀 Starting updates..."
    puts "=" * 80
    puts

    successful_updates = 0
    failed_updates = 0
    
    topics.each_with_index do |topic, index|
      begin
        puts "\n[#{index + 1}/#{topics.count}] Updating Topic #{topic.id}: #{topic.name}"
        puts "-" * 80
        
        # Call the topic:update task programmatically
        Rake::Task['topic:update'].reenable
        Rake::Task['topic:update'].invoke(topic.id.to_s, days.to_s)
        
        successful_updates += 1
        puts "✅ Successfully updated Topic #{topic.id}"
        
      rescue => e
        failed_updates += 1
        puts "❌ Failed to update Topic #{topic.id}: #{e.message}"
        puts e.backtrace.first(3).join("\n") if ENV['DEBUG']
      end
      
      # Re-enable for next iteration
      Rake::Task['topic:update'].reenable
    end

    puts
    puts "=" * 80
    puts "📊 UPDATE SUMMARY"
    puts "=" * 80
    puts "Tag: #{tag.name} (ID: #{tag_id})"
    puts "Days: #{days}"
    puts "Total Topics: #{topics.count}"
    puts "✅ Successful: #{successful_updates}"
    puts "❌ Failed: #{failed_updates}" if failed_updates > 0
    puts "=" * 80
    puts
    
    if successful_updates == topics.count
      puts "🎉 All topics updated successfully!"
      puts
      puts "💡 Next steps:"
      puts "  1. Run diagnostics to verify: rake 'audit:tag:presence[#{tag_id}]'"
      puts "  2. Check PDF reports for affected topics"
      puts "  3. Clear cache if needed: rake cache:clear"
    else
      puts "⚠️  Some updates failed. Check the output above for details."
    end
    puts
  end

  desc 'List all topics using a specific tag'
  task :list_by_tag, [:tag_id] => :environment do |_t, args|
    unless args[:tag_id]
      puts "❌ Error: TAG_ID is required"
      puts "Usage: rake 'topic:list_by_tag[TAG_ID]'"
      exit 1
    end

    tag_id = Integer(args[:tag_id])
    tag = ActsAsTaggableOn::Tag.find_by(id: tag_id)
    
    unless tag
      puts "❌ Error: Tag with ID #{tag_id} not found"
      exit 1
    end

    topics = Topic.joins(:tags).where('tags.id = ?', tag_id).order(:name)
    
    puts "=" * 80
    puts "📋 TOPICS USING TAG"
    puts "=" * 80
    puts "Tag ID: #{tag.id}"
    puts "Tag Name: #{tag.name}"
    puts "Topics Found: #{topics.count}"
    puts "=" * 80
    puts

    if topics.empty?
      puts "⚠️  No topics found using this tag"
    else
      topics.each do |topic|
        # Get other tags for context
        other_tags = topic.tags.where.not(id: tag_id).pluck(:name).join(', ')
        other_tags_info = other_tags.present? ? " (+#{other_tags})" : ""
        
        puts "  [#{topic.id}] #{topic.name}#{other_tags_info}"
      end
      
      puts
      puts "💡 To update all these topics with 60 days:"
      puts "  └─ rake 'topic:update_by_tag[#{tag_id},60]'"
    end
    puts
  end
end


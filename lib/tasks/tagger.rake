# frozen_string_literal: true

desc 'Tagger - Re-tag entries (default: 7 days)'
task :tagger, [:days] => :environment do |_t, args|
  days = args[:days].presence ? Integer(args[:days]) : 7
  
  puts "=" * 80
  puts "🏷️  TAGGER - Re-tagging entries"
  puts "=" * 80
  puts "Range: Last #{days} days"
  puts "Time: #{Time.current.strftime('%Y-%m-%d %H:%M:%S')}"
  puts "=" * 80
  puts
  
  start_date = days.days.ago
  entries = Entry.enabled.where(published_at: start_date..Time.current)
  total = entries.count
  processed = 0
  synced = 0
  
  puts "Total entries to process: #{total}"
  puts
  
  entries.find_each do |entry|
    result = WebExtractorServices::ExtractTags.call(entry.id)
    next unless result.success?

    entry.tag_list = result.data
    puts entry.url
    puts entry.tag_list
    puts entry.published_at
    puts '---------------------------------------------------'

    entry.save!
    
    # Force sync even if tags didn't change
    entry.sync_topics_from_tags if entry.respond_to?(:sync_topics_from_tags)
    
    processed += 1
    synced += 1 if entry.tags.any?
    
    print "\rProcessed: #{processed}/#{total} (#{synced} tagged)" if processed % 50 == 0
  rescue StandardError => e
    puts "\nError processing entry #{entry.id}: #{e.message}"
    processed += 1
    sleep 1
    next
  end
  
  puts "\r" + (" " * 80) # Clear progress line
  puts
  puts "=" * 80
  puts "✅ TAGGER COMPLETE"
  puts "=" * 80
  puts "Processed: #{processed}/#{total}"
  puts "Tagged: #{synced}"
  puts "Duration: Last #{days} days"
  puts "=" * 80
  puts
end

desc 'Retagger - Only entries without tags'
task :retagger, [:days] => :environment do |_t, args|
  days = args[:days].presence ? Integer(args[:days]) : 30
  
  Entry.enabled.where(published_at: days.days.ago..Time.current).find_each do |entry|
    next if entry.tags.any?

    result = WebExtractorServices::ExtractTags.call(entry.id)
    next unless result.success?

    entry.tag_list = result.data
    puts entry.url
    puts entry.tag_list
    puts entry.published_at
    puts '---------------------------------------------------'

    entry.save!
  rescue StandardError => e
    puts e.message
    sleep 1
    retry
  end
end

desc 'Generate tags - Extract names from entries'
task generate_tags: :environment do
  name_regex = /([A-ZÀ-Ö][a-zø-ÿ]{3,}\s[A-ZÀ-Ö][a-zØ-öø-ÿ]{3,}?\s[A-ZÀ-Ö][a-zØ-öø-ÿ]{3,})/
  Entry.enabled.limit(50).each do |entry|
    content = "#{entry.title} #{entry.description}"
    names = content.scan(name_regex)
    puts content
    puts "Names: #{names}"
    puts '---------------------------------------------------'
  end
end

# frozen_string_literal: true

desc 'Tagger'
task tagger: :environment do
  Entry.enabled.where(published_at: 7.days.ago..Time.current).find_each do |entry|
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
  rescue StandardError => e
    puts e.message
    sleep 1
    next
  end
end

task retagger: :environment do
  Entry.enabled.where(published_at: 1.month.ago..Time.current).find_each do |entry|
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

task generate_tags: :environment do
  NAME_REGEX = /([A-ZÀ-Ö][a-zø-ÿ]{3,}\s[A-ZÀ-Ö][a-zØ-öø-ÿ]{3,}?\s[A-ZÀ-Ö][a-zØ-öø-ÿ]{3,})/
  Entry.enabled.limit(50).each do |entry|
    content = "#{entry.title} #{entry.description}"
    names = content.scan(NAME_REGEX)
    puts content
    puts "Names: #{names}"
    puts '---------------------------------------------------'
  end
end

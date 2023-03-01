# frozen_string_literal: true

desc 'Tagger'
task tagger: :environment do
  Entry.where(published_at: 3.months.ago..Time.current).each do |entry|
    result = WebExtractorServices::ExtractTags.call(entry.id)
    next unless result.success?

    entry.tag_list = result.data
    puts entry.url
    puts entry.tag_list
    puts '---------------------------------------------------'

    entry.save!
    entry.touch
  rescue StandardError => e
    puts e.message
    sleep 1
    retry
  end
end

task retagger: :environment do
  Entry.where(published_at: 3.months.ago..Time.current).each do |entry|
    next if entry.tags.any?

    result = WebExtractorServices::ExtractTags.call(entry.id)
    next unless result.success?

    entry.tag_list = result.data
    puts entry.url
    puts entry.tag_list
    puts '---------------------------------------------------'

    entry.save!
    entry.touch
  rescue StandardError => e
    puts e.message
    sleep 1
    retry
  end
end

task generate_tags: :environment do
  NAME_REGEX = /([A-ZÀ-Ö][a-zø-ÿ]{3,}\s[A-ZÀ-Ö][a-zØ-öø-ÿ]{3,}?\s[A-ZÀ-Ö][a-zØ-öø-ÿ]{3,})/
  Entry.limit(50).each do |entry|
    content = "#{entry.title} #{entry.description}"
    names = content.scan(NAME_REGEX)
    puts content
    puts "Names: #{names}"
    puts '---------------------------------------------------'
  end
end

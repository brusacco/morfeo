# frozen_string_literal: true

desc 'Title Tagger'
task title_tagger: :environment do
  Entry.enabled.where(published_at: 3.months.ago..Time.current).find_each do |entry|
    result = WebExtractorServices::ExtractTitleTags.call(entry.id)
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
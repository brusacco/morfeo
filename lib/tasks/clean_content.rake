# frozen_string_literal: true

desc 'Clean content'
task clean_content: :environment do
  words = %w[
    copied
    content
    aling
    important
    right
    left
    margin
    bottom
    inline
    center
    copy
    article
    family
    padding
    float
    clear
    both
    single
  ]
  words.each do |word|
    entries = Entry.find_by_sql("select * from entries where content like \"%#{word}%\" order by published_at DESC")
    Parallel.each(entries, in_threads: 4) do |entry|
      next unless entry.site.content_filter

      doc = Nokogiri::HTML(URI.parse(entry.url).open)
      result = WebExtractorServices::ExtractContent.call(doc, entry.site.content_filter)
      entry.update!(result.data) if result.success?
      puts "Updated #{entry.id} with #{entry.title} #{entry.site.name}"
    rescue StandardError => e
      puts "#{entry.id} had an error: #{entry.title}"
      puts e.message
      next
    end
  end
end

task clean_spaces: :environment do
  entries = Entry.last(10000)
  entries.each do |entry|
    next if entry.content.nil?

    entry.update!(content: entry.content.gsub(/[\n\r\t]/, '').squish)
  end
end

task clean_site_content: :environment do
  site = Site.find(58)
  entries = site.entries.order(published_at: :desc).limit(1000)
  Parallel.each(entries, in_threads: 4) do |entry|
    next unless entry.site.content_filter

    doc = Nokogiri::HTML(URI.parse(entry.url).open.read.force_encoding('UTF-8'))

    #---------------------------------------------------------------------------
    # Basic data extractor
    #---------------------------------------------------------------------------
    result = WebExtractorServices::ExtractBasicInfo.call(doc)
    if result.success?
      entry.update!(result.data)
    else
      puts "ERROR BASIC: #{result.error}"
    end

    #---------------------------------------------------------------------------
    # Content extractor
    #---------------------------------------------------------------------------
    result = WebExtractorServices::ExtractContent.call(doc, entry.site.content_filter)
    if result.success?
      entry.update!(result.data)
    else
      puts "ERROR CONTENT: #{result&.error}"
    end

    #---------------------------------------------------------------------------
    # Tagger
    #---------------------------------------------------------------------------
    result = WebExtractorServices::ExtractTags.call(entry.id)
    if result.success?
      entry.tag_list.add(result.data)
      entry.save!
      puts result.data
    else
      puts "ERROR TAGGER: #{result&.error}"
    end

    puts "Updated #{entry.id} with #{entry.title} #{entry.site.name}"
  rescue StandardError => e
    puts "#{entry.id} had an error: #{entry.title}"
    puts e.message
    next
  end
end

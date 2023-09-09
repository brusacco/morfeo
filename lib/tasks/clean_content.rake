# frozen_string_literal: true

desc 'Clean content'
task clean_content: :environment do
  words = %w[
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

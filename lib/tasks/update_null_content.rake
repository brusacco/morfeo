# frozen_string_literal: true

desc 'Update Null content Entries'
task update_null_content: :environment do
  Entry.where(content: nil, site_id: [6, 8]).order(published_at: :desc).each do |entry|
    if entry.site.content_filter
      doc = Nokogiri::HTML(URI.parse(entry.url).open)
      result = WebExtractorServices::ExtractContent.call(doc, entry.site.content_filter)
      entry.update!(result.data) if result.success?
      puts "Updated #{entry.id} with #{entry.title} #{entry.site.name}"
    end
  rescue StandardError => e
    puts "#{entry.id} had an error: #{entry.title}"
    puts e.message
    next
  end
end

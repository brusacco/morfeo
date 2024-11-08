# frozen_string_literal: true

desc 'Update dates'
task update_dates_test: :environment do
  Parallel.each(Entry.enabled.where(site_id: [110], published_at: nil), in_threads: 3) do |entry|
    begin
      doc = Nokogiri::HTML(URI.parse(entry.url).open)
    rescue StandardError => e
      puts "#{entry.url}: #{e}"
      entry.destroy! if e.message.include?('404')
      next
    end

    result = WebExtractorServices::ExtractDate.call(doc)
    if result.success?
      entry.update!(result.data)
      puts "#{entry.url}: #{result.data}"
    else
      puts "#{entry.url}: #{result.error}"
    end
  rescue StandardError => e
    puts "#{entry.url}: #{e}"
  end
end
# frozen_string_literal: true

desc 'Update dates'
task update_dates: :environment do
  Parallel.each(Entry.where(published_at: nil).order('RANDOM()'), in_threads: 3) do |entry|
    doc = Nokogiri::HTML(URI.parse(entry.url).open)
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

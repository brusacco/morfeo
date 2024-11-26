# frozen_string_literal: true

desc 'Update dates'
task update_dates_test: :environment do
  Parallel.each(Entry.enabled.where(site_id: [74], published_at: nil), in_threads: 3) do |entry|
    begin
      doc = Nokogiri::HTML(URI.parse(entry.url).open("User-Agent" => "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/92.0.4515.159 Safari/537.36"))
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

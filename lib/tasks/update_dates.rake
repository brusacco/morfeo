# frozen_string_literal: true

desc 'Update dates for entries. Usage: rake update_dates[site_id=58,days=7,override=true]'
task :update_dates, %i[site_id days override] => :environment do |_t, args|
  site_id = args[:site_id]
  days = args[:days] ? args[:days].to_i : nil
  override = args[:override] == 'true'

  entries = Entry.enabled
  entries = entries.where(published_at: nil) unless override
  entries = entries.where(site_id: site_id) if site_id
  if days
    days_ago = (Date.today - days).to_date
    entries = entries.where(created_at: days_ago..Date.today)
  end

  puts "Processing #{entries.count} entries (site_id: #{site_id || 'all'}, days: #{days || 'all'}, override: #{override})"

  Parallel.each(entries, in_threads: 3) do |entry|
    begin
      doc = Nokogiri::HTML(URI.parse(entry.url).open('User-Agent' => 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/92.0.4515.159 Safari/537.36'))
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

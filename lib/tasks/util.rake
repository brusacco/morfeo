# frozen_string_literal: true

desc 'Update dates from datetimes'
task update_published_dates: :environment do
  Entry.where(published_date: nil).order(published_at: :desc).each do |entry|
    entry.update!(published_date: entry.published_at.to_date) if entry.published_at
    puts entry.published_date
  rescue StandardError => e
    puts e.message
    sleep 1
    retry
  end
end

task update_basic_content: :environment do
  Parallel.each(Entry.where(published_at: 1.week.ago..Time.current).order("RAND()"), in_threads: 4) do |entry|
    puts entry.url
    content = URI.open(entry.url).read
    doc = Nokogiri::HTML(content)
    #---------------------------------------------------------------------------
    # Basic data extractor
    #---------------------------------------------------------------------------
    result = WebExtractorServices::ExtractBasicInfo.call(doc)
    if result.success?
      entry.update!(result.data)
    else
      puts "ERROR BASIC: #{result.error}"
    end
  rescue StandardError => e
    puts e.message
    next
  end
end

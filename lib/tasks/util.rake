# frozen_string_literal: true

#-------------------------------------------------------------------------------------
#
#-------------------------------------------------------------------------------------
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

#-------------------------------------------------------------------------------------
#
#-------------------------------------------------------------------------------------
task test_openai: :environment do
  OPENAI_TOKEN = Rails.application.credentials[:OPENAI_TOKEN]
  client = OpenAI::Client.new(access_token: OPENAI_TOKEN)

  topic = Topic.find_by(name: 'Honor Colorado')
  tags = topic.tags.pluck(:name)
  entries = Entry.includes(:site).a_week_ago.tagged_with(tags, any: true).order(total_count: :desc).limit(10)
  puts entries.prompt(topic.name)

  puts entries.prompt(topic.name).size

  response = client.chat(
    parameters: {
      model: 'gpt-3.5-turbo', # Required.
      messages: [{ role: 'user', content: entries.prompt(topic.name) }], # Required.
      temperature: 0.7
    }
  )
  puts response.dig('choices', 0, 'message', 'content')
end

#-------------------------------------------------------------------------------------
#
#-------------------------------------------------------------------------------------
task update_basic_content: :environment do
  Parallel.each(Entry.where(published_at: 1.week.ago..Time.current).order('RAND()'), in_threads: 4) do |entry|
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

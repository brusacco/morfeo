# frozen_string_literal: true

desc 'Moopio Morfeo proxy web crawler'
task proxy_crawler: :environment do
  Site.enabled.where(id: 134, is_js: true).each do |site|
    puts "Start processing site #{site.name}..."
    puts '--------------------------------------------------------------------'
    url = "http://api.scrape.do?token=ed138ed418924138923ced2b81e04d53&url=#{CGI.escape(site.url)}&render=True"
    response = HTTParty.get(url, timeout: 60)
    data = JSON.parse(response.body)
    puts data
  end
end

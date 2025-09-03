# frozen_string_literal: true

require 'uri'
require 'net/http'
require 'cgi'

desc 'Moopio Morfeo proxy web crawler'
task proxy_crawler: :environment do
  Site.enabled.where(id: 134, is_js: true).each do |site|
    puts "Start processing site #{site.name}..."
    puts '--------------------------------------------------------------------'
    url = CGI.escape(site.url)
    api_url = URI("http://api.scrape.do?token=ed138ed418924138923ced2b81e04d53&url=#{CGI.escape(url)}")
    https = Net::HTTP.new(api_url.host, api_url.port)
    https.use_ssl = true
    request = Net::HTTP::Get.new(api_url)
    response = https.request(request)
    puts response.read_body
  end
end

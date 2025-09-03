# frozen_string_literal: true

desc 'Moopio Morfeo proxy web crawler'
task proxy_crawler: :environment do
  Site.enabled.where(id: 134, is_js: true).each do |site|
    puts "Start processing site #{site.name}..."
    puts '--------------------------------------------------------------------'

    response = proxy_request(site.url)
    puts response.code
    puts '--------------------------------------------------------------------'

    doc = Nokogiri::HTML(response.body)
    # Process the document as needed
    links = []
    doc.css('a').each do |link|
      puts link.text
      puts link.attribute('href')
      links.push link.attribute('href') if link.attribute('href').to_s.match(/#{site.filter}/)
    end
    links.uniq!
    puts '---------------------------------------------------'
    puts links
  end
end

# def get_links(doc, site)
#   links = []
#   doc.css('a').each do |link|
#     links.push link.attribute('href') if link.attribute('href').to_s.match(/#{site.filter}/)
#   end
#   links.uniq!
# end

def proxy_request(url)
  url = "http://api.scrape.do?token=ed138ed418924138923ced2b81e04d53&url=#{CGI.escape(url)}&render=True"
  HTTParty.get(url, timeout: 60)
end

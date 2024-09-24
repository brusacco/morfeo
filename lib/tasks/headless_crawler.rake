require 'selenium-webdriver'
require 'nokogiri'
require 'open-uri'
require 'webdrivers'

desc "Scrape a web page using Chrome Headless"
task headless_crawler: :environment do
  Site.enabled.where(id: 51).order(total_count: :desc).each do |site|
    options = Selenium::WebDriver::Chrome::Options.new
    options.add_argument('--headless')
    options.add_argument('--no-sandbox')
    options.add_argument('--disable-dev-shm-usage')

    driver = Selenium::WebDriver.for :chrome, options: options

    puts "#{site.name} - #{site.url} - #{site.id}"
    driver.navigate.to site.url

    sleep 10

    links = []
    driver.find_elements(:tag_name, 'a').each do |link|
      puts link.text
      puts link.attribute('href')
      
      if link.attribute('href').to_s.match(/#{site.filter}/)
        links.push link.attribute('href')
        puts 'link ON!'
      else
        puts 'out'
      end
      puts '----------------------------------------------------'
    end
    links.uniq!

    links.each do |link|
      puts link
    end

    # content = driver.page_source
    # puts content

    driver.quit
  end
end

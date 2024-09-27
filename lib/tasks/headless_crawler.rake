require 'selenium-webdriver'
require 'nokogiri'
require 'open-uri'
require 'webdrivers'

desc "Scrape a web page using Chrome Headless"
task headless_crawler: :environment do
  Site.enabled.where(id: 52).order(total_count: :desc).each do |site|
    options = Selenium::WebDriver::Chrome::Options.new
    options.add_argument('--headless')
    options.add_argument('--no-sandbox')
    options.add_argument('--disable-dev-shm-usage')
    options.add_argument('--disable-gpu')
    options.add_argument('--disable-prompt-on-repost')
    options.add_argument('--ignore-certificate-errors')
    options.add_argument('--disable-popup-blocking')
    options.add_argument('--disable-translate')

    user_agent = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/92.0.4515.159 Safari/537.36"
    options.add_argument("--user-agent=#{user_agent}")

    driver = Selenium::WebDriver.for :chrome, options: options
    
    puts "#{site.name} - #{site.url} - #{site.id}"
    driver.navigate.to site.url

    sleep 10
    # driver.manage.timeouts.implicit_wait = 500
    # puts driver
    
    links = []
    driver.find_elements(:tag_name, 'a').each do |link|
      # puts link.text
      # puts link.attribute('href')
      
      if link.attribute('href').to_s.match(/#{site.filter}/)
        links.push link.attribute('href')
      end
    end
    links.uniq!
    
    links.each do |link|
      # puts link

      if entry = Entry.find_by(url: link)
        puts 'NOTICIA YA EXISTE'
        puts entry.title
      else
        driver.navigate.to link
        sleep 10

        content = driver.page_source
        doc = Nokogiri::HTML(content)
        # puts doc

        Entry.create_with(site: site).find_or_create_by!(url: link) do |entry|
          puts entry.url
  
          #---------------------------------------------------------------------------
          # Basic data extractor
          #---------------------------------------------------------------------------
          result = WebExtractorServices::ExtractBasicInfo.call(doc)
          if result.success?
            entry.update!(result.data)
          else
            puts "ERROR BASIC: #{result.error}"
          end
        
          #---------------------------------------------------------------------------
          # Content extractor
          #---------------------------------------------------------------------------
          if entry.site.content_filter.present?
            result = WebExtractorServices::ExtractContent.call(doc, entry.site.content_filter)
            if result.success?
              entry.update!(result.data)
            else
              puts "ERROR CONTENT: #{result&.error}"
            end
          end

          #---------------------------------------------------------------------------
          # Date extractor
          #---------------------------------------------------------------------------
          result = WebExtractorServices::ExtractDate.call(doc)
          if result.success?
            entry.update!(result.data)
            puts result.data
          else
            puts "ERROR DATE: #{result&.error}"
            next
          end

          #---------------------------------------------------------------------------
          # Tagger
          #---------------------------------------------------------------------------
          result = WebExtractorServices::ExtractTags.call(entry.id)
          if result.success?
            entry.tag_list.add(result.data)
            entry.save!
            puts result.data
          else
            puts "ERROR TAGGER: #{result&.error}"
          end

          #---------------------------------------------------------------------------
          # Stats extractor
          #---------------------------------------------------------------------------
          result = FacebookServices::UpdateStats.call(entry.id)
          if result.success?
            entry.update!(result.data)
            puts result.data
          else
            puts "ERROR STATS: #{result&.error}"
          end

          #---------------------------------------------------------------------------
          # Set entry polarity
          #---------------------------------------------------------------------------
          entry.set_polarity if entry.belongs_to_any_topic?
        end
        puts '----------------------------------------------------'
      end
    end

    driver.quit
  end
end

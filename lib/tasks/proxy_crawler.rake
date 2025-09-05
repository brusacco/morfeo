# frozen_string_literal: true

desc 'Moopio Morfeo proxy web crawler'
task proxy_crawler: :environment do
  Site.enabled.where(is_js: true).find_each do |site|
    puts "Start processing site #{site.name}..."
    puts '--------------------------------------------------------------------'

    response = proxy_request(site.url)
    puts response.code
    puts '--------------------------------------------------------------------'

    doc = Nokogiri::HTML(response.body)
    # Process the document as needed
    links = get_links(doc, site)
    puts '--------------------------------------------------------------------'

    links.each do |link|
      # puts link
      check_entry = Entry.find_by(url: link)
      if check_entry
        puts 'NOTICIA YA EXISTE'
        puts check_entry.title
        puts check_entry.url
        puts '------------------------------------------------------'
      else
        content = proxy_request(link).body
        doc = Nokogiri::HTML(content)

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
          # result = FacebookServices::UpdateStats.call(entry.id)
          # if result.success?
          #   entry.update!(result.data)
          #   puts result.data
          # else
          #   puts "ERROR STATS: #{result&.error}"
          # end

          #---------------------------------------------------------------------------
          # Set entry polarity
          #---------------------------------------------------------------------------
          entry.set_polarity if entry.belongs_to_any_topic?
        end
        puts '----------------------------------------------------'
      end
    end
  end
end

def get_links(doc, site)
  links = []
  doc.css('a').each do |link|
    links.push link.attribute('href').to_s if link.attribute('href').to_s.match(/#{site.filter}/)
  end
  links.uniq!
  links
end

def proxy_request(url)
  url = "http://api.scrape.do?token=ed138ed418924138923ced2b81e04d53&url=#{CGI.escape(url)}&render=True"
  attempts = 0
  response = nil
  loop do
    response = HTTParty.get(url, timeout: 60)
    break if response.code == 200 || attempts >= 3

    attempts += 1
  end
  response
end

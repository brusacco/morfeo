# frozen_string_literal: true

desc 'Test de content crawler'
task update_content: :environment do
  Site.where.not(content_filter: nil).each do |site|
    Entry.where(site_id: site.id, content: nil).order(published_at: :desc).limit(1000).each do |entry|
      puts entry.url
      next unless entry.content.nil?
      doc = Nokogiri::HTML.parse(URI.parse(entry.url).open,nil, 'UTF-8')
      result = WebExtractorServices::ExtractContent.call(doc, site.content_filter)
      entry.update!(result.data)
    rescue StandardError => e
      puts "ERROR: #{e.message}"
      next
    end
  end
end

desc 'Moopio Morfeo web crawler'
task test_crawler: :environment do
  Site.where.not(content_filter: nil).each do |site|
    puts "Start processing site #{site.name}..."
    puts '--------------------------------------------------------------------"'
    Anemone.crawl(
      site.url,
      depth_limit: 3,
      discard_page_bodies: true,
      accept_cookies: true,
      verbose: true
    ) do |anemone|
      anemone.skip_links_like(
        /.*(.jpeg|.jpg|.gif|.png|.pdf|.mp3|.mp4|.mpeg).*/,
        %r{/blackhole/},
        %r{/wp-login/},
        %r{/wp-admin/},
        %r{/galerias/},
        %r{/fotoblog/},
        %r{/radios/},
        %r{/page/},
        %r{/etiqueta/},
        %r{/categoria/},
        %r{/category/},
        %r{/wp-content/},
        %r{/tag/}
      )

      anemone.focus_crawl do |page|
        page.links.delete_if { |href| Entry.exists?(url: href.to_s) }
      end

      anemone.on_pages_like(/#{site.filter}/) do |page|
        Entry.create_with(site: site).find_or_create_by!(url: page.url.to_s) do |entry|
          puts entry.url

          #---------------------------------------------------------------------------
          # Basic data extractor
          #---------------------------------------------------------------------------
          result = WebExtractorServices::ExtractBasicInfo.call(page.doc)
          if result.success?
            entry.update!(result.data)
          else
            puts "ERROR BASIC: #{result.error}"
          end


          #---------------------------------------------------------------------------
          # Content data extractor
          #---------------------------------------------------------------------------
          result = WebExtractorServices::ExtractContent.call(page.doc, site.content_filter)
          if result.success?
            entry.update!(result.data)
          else
            puts "ERROR CONTENT: #{result.error}"
          end

          #---------------------------------------------------------------------------
          # Date extractor
          #---------------------------------------------------------------------------
          result = WebExtractorServices::ExtractDate.call(page.doc)
          if result.success?
            entry.update!(result.data)
            puts result.data
          else
            puts "ERROR DATE: #{result.error}"
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
            puts "ERROR TAGGER: #{result.error}"
          end

          #---------------------------------------------------------------------------
          # Stats extractor
          #---------------------------------------------------------------------------
          result = FacebookServices::UpdateStats.call(entry.id)
          if result.success?
            entry.update!(result.data) if result.success?
            puts result.data
          else
            puts "ERROR STATS: #{result.error}"
          end

          puts '----------------------------------------------------------------------'
        end
      end
    end
  rescue StandardError => e
    puts e.message
    next
  end
end

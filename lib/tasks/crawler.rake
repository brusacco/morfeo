# frozen_string_literal: true

desc 'Moopio Morfeo web crawler'
task crawler: :environment do
  Site.all.each do |site|
    puts "Start processing site #{site.name}..."
    Anemone.crawl(
      site.url,
      depth_limit: 1,
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
        %r{/tag/}
      )

      #anemone.focus_crawl do |page|
        #page.links.delete_if { |href| Entry.exists?(url: href.to_s) }
      #end

      anemone.on_pages_like(/#{site.filter}/) do |page|
        Entry.create_with(site: site).find_or_create_by!(url: page.url.to_s) do |entry|
          puts entry.url

          # Basic data extractor
          result = WebExtractorServices::ExtractBasicInfo.call(page.doc)
          entry.update!(result.data) if result.success?

          # Date extractor
          result = WebExtractorServices::ExtractDate.call(page.doc)
          entry.update!(result.data) if result.success?
          puts result.data

          # Tagger
          result = WebExtractorServices::ExtractTags.call(entry.id)
          if result.success?
            entry.tag_list.add(result.data)
            entry.save!
            puts result.data
          end

          # Stats extractor
          result = FacebookServices::UpdateStats.call(entry.id)
          entry.update!(result.data) if result.success?

          puts result.data
          puts '-----------------------------------------'
        end
      end
    end
  rescue StandardError => e
    puts e.message
    next
  end
end

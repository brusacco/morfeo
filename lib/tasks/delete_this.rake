# frozen_string_literal: true

desc 'Moopio Morfeo web crawler'
task crawler_test: :environment do
  directories = %w[
    blackhole
    wp-login
    wp-admin
    galerias
    fotoblog
    radios
    page
    etiqueta
    categoria
    category
    pagina
    auth
    wp-content
    img
    tag
    contacto
    programa
    date
    feed
  ]
  directory_pattern = /#{directories.join('|')}/
  Site.where(id: 8).order(total_count: :desc).each do |site|
    puts "Start test processing site #{site.name}..."
    puts '--------------------------------------------------------------------"'
    Anemone.crawl(
      site.url,
      depth_limit: 3,
      discard_page_bodies: true,
      accept_cookies: true,
      threads: 5,
      verbose: true
    ) do |anemone|
      anemone.skip_links_like(/.*\.(jpeg|jpg|gif|png|pdf|mp3|mp4|mpeg)/, directory_pattern)

      anemone.focus_crawl do |page|
        # page.links.delete_if { |href| Entry.exists?(url: href.to_s) }
        page.links.delete_if do |href|
          href.to_s.match(/#{site.negative_filter.presence || 'NUNCA'}/).present?
        end
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
          # Content extractor
          #---------------------------------------------------------------------------
          if entry.site.content_filter.present?
            result = WebExtractorServices::ExtractContent.call(page.doc, entry.site.content_filter)
            if result.success?
              entry.update!(result.data)
            else
              puts "ERROR CONTENT: #{result&.error}"
            end
          end

          #---------------------------------------------------------------------------
          # Date extractor
          #---------------------------------------------------------------------------
          result = WebExtractorServices::ExtractDate.call(page.doc)
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
            entry.update!(result.data) if result.success?
            puts result.data
          else
            puts "ERROR STATS: #{result&.error}"
          end

          #---------------------------------------------------------------------------
          # Extract and save ngrams
          #---------------------------------------------------------------------------
          # entry.bigrams
          # entry.trigrams
          puts '----------------------------------------------------------------------'
        end
      rescue StandardError => e
        puts e.message
        next
      end
    end
  end
end

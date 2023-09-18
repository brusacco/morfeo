# frozen_string_literal: true

module WebExtractorServices
  class UrlCrawler < ApplicationService
    def initialize(url, site, uid = nil)
      @url = url
      @site = site
      @uid = uid
    end

    def call
      return handle_error('URL dont match') unless @url.match(@site.filter)
      return handle_error('URL alread exist') if Entry.exists?(url: @url)

      doc = Nokogiri::HTML(URI.parse(@url).open.read.force_encoding('UTF-8'))
      Entry.create_with(site: @site, uid: @uid).find_or_create_by!(url: @url) do |entry|
        #---------------------------------------------------------------------------
        # Basic data extractor
        #---------------------------------------------------------------------------
        result = WebExtractorServices::ExtractBasicInfo.call(doc)
        entry.update!(result.data) if result.success?

        #---------------------------------------------------------------------------
        # Content extractor
        #---------------------------------------------------------------------------
        if entry.site.content_filter.present?
          result = WebExtractorServices::ExtractContent.call(doc, entry.site.content_filter)
          entry.update!(result.data) if result.success?
        end

        #---------------------------------------------------------------------------
        # Date extractor
        #---------------------------------------------------------------------------
        result = WebExtractorServices::ExtractDate.call(doc)
        entry.update!(result.data) if result.success?

        #---------------------------------------------------------------------------
        # Tagger
        #---------------------------------------------------------------------------
        result = WebExtractorServices::ExtractTags.call(entry.id)
        if result.success?
          entry.tag_list.add(result.data)
          entry.save!
        end

        #---------------------------------------------------------------------------
        # Stats extractor
        #---------------------------------------------------------------------------
        result = FacebookServices::UpdateStats.call(entry.id)
        entry.update!(result.data) if result.success?
      end
      handle_success(@url)
    rescue StandardError => e
      handle_error(e.message)
    end
  end
end

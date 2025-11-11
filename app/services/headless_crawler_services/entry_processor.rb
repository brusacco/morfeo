# frozen_string_literal: true

module HeadlessCrawlerServices
  # Processes individual article entries: extraction, creation, and enrichment
  class EntryProcessor < ApplicationService
    def initialize(driver:, site:, url:, skip_exist_check: false)
      @driver = driver
      @site = site
      @url = url
      @skip_exist_check = skip_exist_check
    end

    def call
      # Check if entry already exists (unless already checked in batch)
      unless @skip_exist_check
        existing_entry = Entry.find_by(url: @url)
        if existing_entry
          Rails.logger.info("Entry already exists: #{existing_entry.title}")
          return handle_success(entry: existing_entry, created: false)
        end
      end

      # Navigate to article page
      BrowserManager.navigate_to(@driver, @url, site: @site)

      # Parse page content
      doc = parse_page_content

      # Create and enrich entry
      entry = create_entry(doc)
      enrich_entry(entry, doc)

      Rails.logger.info("Successfully processed: #{entry.title}")
      handle_success(entry: entry, created: true)
    rescue StandardError => e
      Rails.logger.error("EntryProcessor error for #{@url}: #{e.message}")
      Rails.logger.error(e.backtrace.first(5).join("\n"))
      handle_error(e.message)
    end

    private

    def parse_page_content
      content = @driver.page_source
      Nokogiri::HTML(content)
    end

    def create_entry(doc)
      Entry.create_with(site: @site).find_or_create_by!(url: @url) do |entry|
        # Extract basic information
        extract_basic_info(entry, doc)
        
        # Extract content if filter available
        extract_content(entry, doc) if @site.content_filter.present?
        
        # Extract and validate publication date
        extract_date(entry, doc)
      end
    end

    def enrich_entry(entry, doc)
      # Batch all enrichment data
      enrichment_data = {}

      # Extract tags
      tags = extract_tags(entry)
      
      # Extract Facebook stats
      stats = extract_facebook_stats(entry)
      enrichment_data.merge!(stats) if stats.present?

      # Single database update with all enrichment data
      if enrichment_data.present?
        entry.update!(enrichment_data)
      end

      # Update tags separately (uses acts_as_taggable_on)
      if tags.present?
        entry.tag_list.add(tags)
        entry.save!
      end

      # Set sentiment polarity if entry belongs to any monitored topic
      entry.set_polarity if entry.belongs_to_any_topic?

      entry
    end

    # =========================================================================
    # Extraction Methods
    # =========================================================================

    def extract_basic_info(entry, doc)
      result = WebExtractorServices::ExtractBasicInfo.call(doc)
      
      if result.success?
        entry.assign_attributes(result.data)
      else
        Rails.logger.warn("Basic info extraction failed: #{result.error}")
      end
    end

    def extract_content(entry, doc)
      result = WebExtractorServices::ExtractContent.call(doc, @site.content_filter)
      
      if result.success?
        entry.assign_attributes(result.data)
      else
        Rails.logger.warn("Content extraction failed: #{result.error}")
      end
    end

    def extract_date(entry, doc)
      result = WebExtractorServices::ExtractDate.call(doc)
      
      if result.success?
        entry.assign_attributes(result.data)
        Rails.logger.debug("Date extracted: #{result.data}")
      else
        Rails.logger.error("Date extraction failed: #{result.error}")
        # Date is critical - raise exception if missing
        raise "Date extraction failed for #{@url}"
      end
    end

    def extract_tags(entry)
      result = WebExtractorServices::ExtractTags.call(entry.id)
      
      if result.success?
        result.data
      else
        Rails.logger.warn("Tag extraction failed: #{result.error}")
        []
      end
    end

    def extract_facebook_stats(entry)
      result = FacebookServices::UpdateStats.call(entry.id)
      
      if result.success?
        result.data
      else
        Rails.logger.debug("Facebook stats extraction failed: #{result.error}")
        nil
      end
    end
  end
end


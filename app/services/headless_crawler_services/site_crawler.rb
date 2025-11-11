# frozen_string_literal: true

module HeadlessCrawlerServices
  # Crawls a single site: navigates to homepage, extracts links, processes articles
  class SiteCrawler < ApplicationService
    MAX_RETRIES = 3
    RETRY_DELAY = 5 # seconds

    def initialize(site:, driver:)
      @site = site
      @driver = driver
      @stats = {
        total_links: 0,
        existing_entries: 0,
        new_entries: 0,
        failed_entries: 0,
        errors: []
      }
    end

    def call
      Rails.logger.info("=" * 80)
      Rails.logger.info("Processing site: #{@site.name} (#{@site.url}) [ID: #{@site.id}]")
      Rails.logger.info("=" * 80)

      # Navigate to site homepage
      navigate_to_homepage

      # Extract article links
      links = extract_article_links
      return ServiceResult.failure(error: "No links found") if links.empty?

      # Process each article
      process_articles(links)

      # Log summary
      log_summary

      ServiceResult.success(stats: @stats)
    rescue StandardError => e
      Rails.logger.error("SiteCrawler failed for #{@site.name}: #{e.message}")
      Rails.logger.error(e.backtrace.first(10).join("\n"))
      ServiceResult.failure(error: e.message, stats: @stats)
    end

    private

    def navigate_to_homepage
      BrowserManager.navigate_to(@driver, @site.url, retries: MAX_RETRIES)
    rescue StandardError => e
      Rails.logger.error("Failed to navigate to #{@site.url}: #{e.message}")
      raise
    end

    def extract_article_links
      result = LinkExtractor.call(driver: @driver, site: @site)
      
      unless result.success?
        Rails.logger.error("Link extraction failed: #{result.error}")
        return []
      end

      links = result.links
      @stats[:total_links] = links.size
      
      Rails.logger.info("Found #{links.size} article links")
      links
    end

    def process_articles(links)
      links.each_with_index do |link, index|
        process_single_article(link, index + 1, links.size)
        
        # Brief pause between articles to avoid rate limiting
        sleep(1) if index < links.size - 1
      end
    end

    def process_single_article(link, current, total)
      Rails.logger.info("-" * 80)
      Rails.logger.info("Processing article #{current}/#{total}: #{link}")
      
      result = EntryProcessor.call(driver: @driver, site: @site, url: link)
      
      if result.success?
        if result.created
          @stats[:new_entries] += 1
          Rails.logger.info("✓ New entry created")
        else
          @stats[:existing_entries] += 1
          Rails.logger.info("○ Entry already exists")
        end
      else
        @stats[:failed_entries] += 1
        @stats[:errors] << { url: link, error: result.error }
        Rails.logger.error("✗ Failed to process entry: #{result.error}")
      end
    rescue StandardError => e
      @stats[:failed_entries] += 1
      @stats[:errors] << { url: link, error: e.message }
      Rails.logger.error("✗ Unexpected error: #{e.message}")
    end

    def log_summary
      Rails.logger.info("")
      Rails.logger.info("=" * 80)
      Rails.logger.info("SUMMARY for #{@site.name}")
      Rails.logger.info("=" * 80)
      Rails.logger.info("Total links found:    #{@stats[:total_links]}")
      Rails.logger.info("New entries created:  #{@stats[:new_entries]}")
      Rails.logger.info("Existing entries:     #{@stats[:existing_entries]}")
      Rails.logger.info("Failed entries:       #{@stats[:failed_entries]}")
      
      if @stats[:errors].any?
        Rails.logger.info("")
        Rails.logger.info("ERRORS:")
        @stats[:errors].first(5).each do |error|
          Rails.logger.info("  - #{error[:url]}: #{error[:error]}")
        end
        Rails.logger.info("  ... and #{@stats[:errors].size - 5} more") if @stats[:errors].size > 5
      end
      
      Rails.logger.info("=" * 80)
    end
  end
end


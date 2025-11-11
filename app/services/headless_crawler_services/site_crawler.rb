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
      puts "Processing site: #{@site.name} (#{@site.url}) [ID: #{@site.id}]"
      puts "=" * 80
      
      Rails.logger.info("=" * 80)
      Rails.logger.info("Processing site: #{@site.name} (#{@site.url}) [ID: #{@site.id}]")
      Rails.logger.info("=" * 80)

      # Navigate to site homepage
      navigate_to_homepage

      # Extract article links
      links = extract_article_links
      return handle_error("No links found") if links.empty?

      # Process each article
      process_articles(links)

      # Log summary
      log_summary

      handle_success(stats: @stats)
    rescue StandardError => e
      Rails.logger.error("SiteCrawler failed for #{@site.name}: #{e.message}")
      Rails.logger.error(e.backtrace.first(10).join("\n"))
      handle_error(e.message)
    end

    private

    def navigate_to_homepage
      # Homepage doesn't need content_filter - only article pages use waitSelector
      BrowserManager.navigate_to(@driver, @site.url, retries: MAX_RETRIES, site: nil)
    rescue StandardError => e
      Rails.logger.error("Failed to navigate to #{@site.url}: #{e.message}")
      raise
    end

    def extract_article_links
      result = LinkExtractor.call(driver: @driver, site: @site)
      
      unless result.success?
        Rails.logger.error("Link extraction failed: #{result.error}")
        puts "❌ Link extraction failed: #{result.error}"
        return []
      end

      links = result.links
      @stats[:total_links] = links.size
      
      puts "🔗 Found #{links.size} article link(s)"
      Rails.logger.info("Found #{links.size} article links")
      links
    end

    def process_articles(links)
      # Batch check: Find which URLs already exist in DB (MUCH faster)
      existing_urls = Entry.where(url: links).pluck(:url).to_set
      new_links = links.reject { |link| existing_urls.include?(link) }
      
      puts "\n📊 Quick Analysis:"
      puts "   Total links: #{links.size}"
      puts "   Already in DB: #{existing_urls.size} (will skip)"
      puts "   New to process: #{new_links.size}"
      puts ""
      
      # Process only new links (skip existing ones)
      if new_links.empty?
        puts "✓ All articles already exist in database (nothing to process)"
        @stats[:existing_entries] = links.size
        return
      end
      
      # Process new links
      new_links.each_with_index do |link, index|
        original_index = links.index(link) + 1
        process_single_article(link, original_index, links.size, skip_exist_check: true)
        
        # Brief pause between articles to avoid rate limiting
        sleep(1) if index < new_links.size - 1
      end
      
      # Update stats for skipped entries
      @stats[:existing_entries] = existing_urls.size
    end

    def process_single_article(link, current, total, skip_exist_check: false)
      puts "   [#{current}/#{total}] #{link[0..80]}..."
      
      Rails.logger.info("-" * 80)
      Rails.logger.info("Processing article #{current}/#{total}: #{link}")
      
      result = EntryProcessor.call(
        driver: @driver, 
        site: @site, 
        url: link,
        skip_exist_check: skip_exist_check
      )
      
      if result.success?
        if result.created
          @stats[:new_entries] += 1
          print " ✓"
          Rails.logger.info("✓ New entry created")
        else
          @stats[:existing_entries] += 1
          print " ○"
          Rails.logger.info("○ Entry already exists")
        end
      else
        @stats[:failed_entries] += 1
        @stats[:errors] << { url: link, error: result.error }
        print " ✗"
        Rails.logger.error("✗ Failed to process entry: #{result.error}")
      end
    rescue StandardError => e
      @stats[:failed_entries] += 1
      @stats[:errors] << { url: link, error: e.message }
      print " ✗"
      Rails.logger.error("✗ Unexpected error: #{e.message}")
    end

    def log_summary
      puts "\n"
      puts "=" * 80
      puts "SUMMARY for #{@site.name}"
      puts "=" * 80
      puts "Total links found:    #{@stats[:total_links]}"
      puts "New entries created:  #{@stats[:new_entries]}"
      puts "Existing entries:     #{@stats[:existing_entries]}"
      puts "Failed entries:       #{@stats[:failed_entries]}"
      
      if @stats[:errors].any?
        puts "\nERRORS:"
        @stats[:errors].first(3).each do |error|
          puts "  - #{error[:url][0..60]}... : #{error[:error]}"
        end
        puts "  ... and #{@stats[:errors].size - 3} more" if @stats[:errors].size > 3
      end
      
      puts "=" * 80
      
      # Also log to Rails logger
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


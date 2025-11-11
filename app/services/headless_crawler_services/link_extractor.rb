# frozen_string_literal: true

module HeadlessCrawlerServices
  # Extracts and filters article links from a site's homepage
  class LinkExtractor < ApplicationService
    def initialize(driver:, site:)
      @driver = driver
      @site = site
    end

    def call
      links = extract_links
      filtered_links = filter_links(links)
      
      Rails.logger.info("Extracted #{filtered_links.size} valid links from #{@site.name}")
      
      ServiceResult.success(links: filtered_links)
    rescue StandardError => e
      Rails.logger.error("LinkExtractor error for #{@site.name}: #{e.message}")
      ServiceResult.failure(error: e.message)
    end

    private

    def extract_links
      links = []
      
      @driver.find_elements(:tag_name, 'a').each do |link_element|
        href = link_element.attribute('href')
        next unless href.present?
        
        links << href if matches_site_filter?(href)
      rescue StandardError => e
        # Continue processing other links if one fails
        Rails.logger.debug("Error extracting link: #{e.message}")
      end
      
      links
    end

    def filter_links(links)
      # Remove duplicates and sort for consistent processing
      links.uniq.sort
    end

    def matches_site_filter?(url)
      return false unless @site.filter.present?
      
      url.to_s.match?(/#{Regexp.escape(@site.filter)}/)
    rescue RegexpError => e
      Rails.logger.error("Invalid regex filter for #{@site.name}: #{e.message}")
      false
    end
  end
end


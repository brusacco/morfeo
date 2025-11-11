# frozen_string_literal: true

module ProxyCrawlerServices
  # Extracts and filters article links from a site's homepage
  # Same functionality as HeadlessCrawlerServices::LinkExtractor but for proxy-fetched content
  class LinkExtractor < ApplicationService
    def initialize(document:, site:)
      @doc = document
      @site = site
    end

    def call
      all_links = extract_all_links
      filtered_links = filter_links(all_links[:matched_links])
      
      puts "\n🔍 Link Extraction Debug for #{@site.name}:"
      puts "   Total <a> tags found: #{all_links[:total_links]}"
      puts "   With href attribute: #{all_links[:links_with_href]}"
      puts "   Matching filter: #{filtered_links.size}"
      
      if filtered_links.empty? && all_links[:links_with_href] > 0
        puts "\n⚠️  WARNING: Found links but NONE matched the filter!"
        puts "   Filter: #{@site.filter}"
        puts "\n   Sample links found (first 5):"
        all_links[:sample_links].first(5).each do |link|
          puts "     - #{link}"
        end
        puts "\n   💡 Tip: Check if the filter regex is correct in ActiveAdmin"
      end
      
      Rails.logger.info("Extracted #{filtered_links.size} valid links from #{@site.name}")
      Rails.logger.debug("Total links: #{all_links[:total_links]}, With href: #{all_links[:links_with_href]}, Matched: #{filtered_links.size}")
      
      handle_success(links: filtered_links)
    rescue StandardError => e
      Rails.logger.error("LinkExtractor error for #{@site.name}: #{e.message}")
      handle_error(e.message)
    end

    private

    def extract_all_links
      all_links = []
      matched_links = []
      total_count = 0
      
      @doc.css('a').each do |link_element|
        total_count += 1
        href = link_element.attribute('href')&.to_s
        
        if href.present?
          all_links << href
          matched_links << href if matches_site_filter?(href)
        end
      rescue StandardError => e
        # Continue processing other links if one fails
        Rails.logger.debug("Error extracting link: #{e.message}")
      end
      
      {
        total_links: total_count,
        links_with_href: all_links.size,
        sample_links: all_links.uniq,
        matched_links: matched_links
      }
    end

    def filter_links(links)
      # Remove duplicates and sort for consistent processing
      links.uniq.sort
    end

    def matches_site_filter?(url)
      return false unless @site.filter.present?
      
      # Don't escape the filter - it's already a regex pattern!
      url.match?(/#{@site.filter}/)
    rescue RegexpError => e
      Rails.logger.error("Invalid regex filter for #{@site.name}: #{e.message}")
      Rails.logger.error("Filter causing error: #{@site.filter}")
      false
    end
  end
end


# frozen_string_literal: true

module HeadlessCrawlerServices
  # Main orchestrator for headless crawler
  # Manages browser lifecycle and coordinates site crawling
  class Orchestrator < ApplicationService
    def initialize(site_ids: nil, limit: nil, use_proxy: false)
      @site_ids = site_ids
      @limit = limit
      @use_proxy = use_proxy
      @overall_stats = {
        sites_processed: 0,
        sites_failed: 0,
        total_new_entries: 0,
        total_existing_entries: 0,
        total_failed_entries: 0
      }
    end

    def call
      sites = fetch_sites
      
      if sites.empty?
        message = "No JavaScript-enabled sites found to process"
        Rails.logger.warn(message)
        puts "\n⚠️  #{message}"
        puts "\nTo enable sites for headless crawling:"
        puts "  1. Go to ActiveAdmin"
        puts "  2. Edit a Site"
        puts "  3. Check 'Is JS' checkbox"
        puts "  4. Save and run again"
        return handle_success(stats: @overall_stats, message: message)
      end

      Rails.logger.info("Starting headless crawler for #{sites.size} site(s)")
      puts "\n📋 Found #{sites.size} site(s) to process:"
      sites.each_with_index do |site, index|
        puts "   #{index + 1}. #{site.name} (ID: #{site.id})"
      end
      puts ""
      
      start_time = Time.current

      # Process sites with browser management
      process_sites(sites)

      # Log overall summary
      log_overall_summary(start_time)

      handle_success(stats: @overall_stats)
    rescue StandardError => e
      Rails.logger.error("Orchestrator failed: #{e.message}")
      Rails.logger.error(e.backtrace.first(10).join("\n"))
      handle_error(e.message)
    end

    private

    def fetch_sites
      sites = Site.enabled.where(is_js: true)
      sites = sites.where(id: @site_ids) if @site_ids.present?
      sites = sites.order(total_count: :desc)
      sites = sites.limit(@limit) if @limit.present?
      sites
    end

    def process_sites(sites)
      proxy_msg = @use_proxy ? " with scrape.do proxy" : ""
      puts "\n🌐 Initializing Chrome browser#{proxy_msg}..."
      Rails.logger.info("Initializing browser for #{sites.size} site(s), use_proxy: #{@use_proxy}")

      # Use browser manager with automatic cleanup
      result = BrowserManager.call(use_proxy: @use_proxy) do |driver|
        puts "✓ Browser ready\n"
        Rails.logger.info("Browser initialized successfully")

        sites.each_with_index do |site, index|
          process_single_site(site, driver, index + 1, sites.size)
        end
      end
      
      unless result.success?
        puts "\n❌ Browser initialization failed: #{result.error}"
        Rails.logger.error("Browser initialization failed: #{result.error}")
      end
    rescue StandardError => e
      puts "\n❌ Error in process_sites: #{e.message}"
      puts e.backtrace.first(5).join("\n")
      Rails.logger.error("Error in process_sites: #{e.message}")
      Rails.logger.error(e.backtrace.join("\n"))
      raise
    end

    def process_single_site(site, driver, current, total)
      puts ""
      puts "╔" + "═" * 78 + "╗"
      puts "║ SITE #{current}/#{total}: #{site.name.center(70)} ║"
      puts "╚" + "═" * 78 + "╝"
      puts ""
      
      Rails.logger.info("=" * 80)
      Rails.logger.info("SITE #{current}/#{total}: #{site.name}")
      Rails.logger.info("=" * 80)

      result = SiteCrawler.call(site: site, driver: driver)

      if result.success?
        update_overall_stats(result.stats, success: true)
      else
        Rails.logger.error("Site processing failed: #{result.error}")
        update_overall_stats(result.stats, success: false)
      end
    rescue StandardError => e
      Rails.logger.error("Unexpected error processing #{site.name}: #{e.message}")
      @overall_stats[:sites_failed] += 1
    end

    def update_overall_stats(site_stats, success:)
      if success
        @overall_stats[:sites_processed] += 1
      else
        @overall_stats[:sites_failed] += 1
      end

      @overall_stats[:total_new_entries] += site_stats[:new_entries] || 0
      @overall_stats[:total_existing_entries] += site_stats[:existing_entries] || 0
      @overall_stats[:total_failed_entries] += site_stats[:failed_entries] || 0
    end

    def log_overall_summary(start_time)
      duration = Time.current - start_time
      
      puts ""
      puts "╔" + "═" * 78 + "╗"
      puts "║" + " OVERALL SUMMARY ".center(78) + "║"
      puts "╠" + "═" * 78 + "╣"
      puts "║ Duration:             #{format_duration(duration).ljust(58)} ║"
      puts "║ Sites processed:      #{@overall_stats[:sites_processed].to_s.ljust(58)} ║"
      puts "║ Sites failed:         #{@overall_stats[:sites_failed].to_s.ljust(58)} ║"
      puts "║ Total new entries:    #{@overall_stats[:total_new_entries].to_s.ljust(58)} ║"
      puts "║ Total existing:       #{@overall_stats[:total_existing_entries].to_s.ljust(58)} ║"
      puts "║ Total failed:         #{@overall_stats[:total_failed_entries].to_s.ljust(58)} ║"
      puts "╚" + "═" * 78 + "╝"
      
      # Also log to Rails logger
      Rails.logger.info("=" * 80)
      Rails.logger.info("OVERALL SUMMARY")
      Rails.logger.info("=" * 80)
      Rails.logger.info("Duration:          #{format_duration(duration)}")
      Rails.logger.info("Sites processed:   #{@overall_stats[:sites_processed]}")
      Rails.logger.info("Sites failed:      #{@overall_stats[:sites_failed]}")
      Rails.logger.info("Total new entries: #{@overall_stats[:total_new_entries]}")
      Rails.logger.info("Total existing:    #{@overall_stats[:total_existing_entries]}")
      Rails.logger.info("Total failed:      #{@overall_stats[:total_failed_entries]}")
      Rails.logger.info("=" * 80)
    end

    def format_duration(seconds)
      minutes = (seconds / 60).to_i
      remaining_seconds = (seconds % 60).to_i
      "#{minutes}m #{remaining_seconds}s"
    end
  end
end


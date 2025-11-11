# frozen_string_literal: true

namespace :crawler do
  desc 'Show diagnostic information about sites configured for headless crawling'
  task diagnostics: :environment do
    puts "\n" + "=" * 80
    puts "HEADLESS CRAWLER DIAGNOSTICS"
    puts "=" * 80
    
    # All sites with is_js = true
    all_js_sites = Site.where(is_js: true)
    puts "\n📊 Total sites with is_js = true: #{all_js_sites.count}"
    
    if all_js_sites.any?
      puts "\nAll JS sites:"
      all_js_sites.each do |site|
        status_icon = site.status ? "✓" : "✗"
        puts "  #{status_icon} [ID: #{site.id}] #{site.name}"
        puts "      URL: #{site.url}"
        puts "      Status: #{site.status ? 'enabled' : 'DISABLED'}"
        puts "      Filter: #{site.filter.present? ? site.filter : '(none)'}"
        puts ""
      end
    end
    
    # Enabled sites with is_js = true (what the crawler will use)
    enabled_js_sites = Site.enabled.where(is_js: true)
    puts "\n🎯 Sites that crawler will process (enabled + is_js = true): #{enabled_js_sites.count}"
    
    if enabled_js_sites.any?
      puts "\nSites ready for crawling:"
      enabled_js_sites.order(total_count: :desc).each do |site|
        puts "  ✓ [ID: #{site.id}] #{site.name}"
        puts "      URL: #{site.url}"
        puts "      Filter: #{site.filter.present? ? site.filter : '(none)'}"
        puts "      Total Count: #{site.total_count}"
        puts ""
      end
    else
      puts "\n⚠️  WARNING: No sites will be processed!"
      puts "\nPossible reasons:"
      puts "  1. Sites have is_js = true but status = false (disabled)"
      puts "  2. Check Site.enabled scope definition"
      puts ""
    end
    
    # Check Site.enabled scope
    puts "\n🔍 Checking Site.enabled scope..."
    begin
      if Site.respond_to?(:enabled)
        puts "  ✓ Site.enabled scope exists"
        enabled_count = Site.enabled.count
        total_count = Site.count
        puts "  📊 Site.enabled: #{enabled_count} / #{total_count} total sites"
      else
        puts "  ✗ Site.enabled scope does NOT exist"
        puts "    The crawler expects this scope to filter active sites"
      end
    rescue => e
      puts "  ✗ Error checking Site.enabled: #{e.message}"
    end
    
    # Recommendations
    puts "\n" + "=" * 80
    puts "RECOMMENDATIONS"
    puts "=" * 80
    
    if enabled_js_sites.empty?
      puts "\n❌ No sites configured for headless crawling!"
      puts "\nTo fix:"
      puts "  1. Go to ActiveAdmin → Sites"
      puts "  2. Edit a site that requires JavaScript"
      puts "  3. Make sure both checkboxes are checked:"
      puts "     □ Status (enabled)"
      puts "     □ Is JS (requires headless browser)"
      puts "  4. Save and run: rake crawler:headless"
    else
      puts "\n✅ #{enabled_js_sites.count} site(s) ready for crawling"
      puts "\nTo test:"
      puts "  rake crawler:headless:test[1]      # Test with 1 site"
      puts "  rake crawler:headless              # Process all sites"
      puts "  rake crawler:headless:site[#{enabled_js_sites.first.id}]  # Test specific site"
    end
    
    puts "\n" + "=" * 80
  end
end



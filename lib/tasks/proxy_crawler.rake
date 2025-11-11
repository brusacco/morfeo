# frozen_string_literal: true

namespace :crawler do
  desc 'Scrape JavaScript-rendered news sites using scrape.do proxy service'
  task proxy: :environment do
    puts "\n🚀 Starting Proxy Crawler..."
    puts "=" * 80

    result = ProxyCrawlerServices::Orchestrator.call

    if result.success?
      puts "\n✅ Crawler completed successfully!"
      exit 0
    else
      puts "\n❌ Crawler failed: #{result.error}"
      exit 1
    end
  end

  desc 'Scrape specific site(s) by ID using proxy - Usage: rake crawler:proxy:site[1,2,3]'
  task :proxy_site, [:site_ids] => :environment do |_t, args|
    site_ids = args[:site_ids].to_s.split(',').map { |id| Integer(id, 10) }

    if site_ids.empty?
      puts "❌ Please provide at least one site ID"
      puts "Usage: rake crawler:proxy:site[1,2,3]"
      exit 1
    end

    puts "\n🚀 Starting Proxy Crawler for specific sites..."
    puts "Sites: #{site_ids.join(', ')}"
    puts "=" * 80

    result = ProxyCrawlerServices::Orchestrator.call(site_ids: site_ids)

    if result.success?
      puts "\n✅ Crawler completed successfully!"
      exit 0
    else
      puts "\n❌ Crawler failed: #{result.error}"
      exit 1
    end
  end

  desc 'Test proxy crawler with first N sites - Usage: rake crawler:proxy:test[5]'
  task :proxy_test, [:limit] => :environment do |_t, args|
    limit = args[:limit] ? Integer(args[:limit], 10) : 1

    puts "\n🧪 Testing Proxy Crawler with #{limit} site(s)..."
    puts "=" * 80

    result = ProxyCrawlerServices::Orchestrator.call(limit: limit)

    if result.success?
      puts "\n✅ Test completed successfully!"
      exit 0
    else
      puts "\n❌ Test failed: #{result.error}"
      exit 1
    end
  end
end

# Backward compatibility: keep old task name pointing to new implementation
desc 'Scrape JavaScript-rendered news sites using proxy (alias for crawler:proxy)'
task proxy_crawler: 'crawler:proxy'

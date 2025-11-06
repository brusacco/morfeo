# frozen_string_literal: true

namespace :facebook do
  desc 'Facebook crawler with configurable pagination (default: 3 pages = ~300 posts per page)'
  task :fanpage_crawler, [:max_pages] => :environment do |_t, args|
    # Parse max_pages argument (default: 3, each page = ~100 posts)
    max_pages = (args[:max_pages] || 3).to_i

    # Validate max_pages (1-10 range)
    unless (1..10).include?(max_pages)
      Rails.logger.error "Invalid max_pages: #{max_pages}. Must be between 1 and 10."
      puts "❌ Error: max_pages must be between 1 and 10 (got: #{max_pages})"
      exit 1
    end

    Rails.logger.info "Starting Facebook crawler with max #{max_pages} pages per fanpage"
    puts "\n" + "=" * 80
    puts "FACEBOOK FANPAGE CRAWLER"
    puts "=" * 80
    puts "Max pages per fanpage: #{max_pages} (#{max_pages * 100} posts max)"
    puts "=" * 80 + "\n"

    Page.find_each do |page|
      cursor = nil
      page_count = 0

      puts "\n[#{page.name}] Starting crawl..."

      loop do
        page_count += 1
        label = cursor.present? ? "cursor: #{cursor[0..10]}..." : "page: #{page_count}"
        puts "  [Page #{page_count}/#{max_pages}] Processing #{label}..."

        response = FacebookServices::FanpageCrawler.call(page.uid, cursor)
        unless response.success?
          error_msg = response.error.to_s
          Rails.logger.error "[FacebookCrawler] Error crawling #{page.name}: #{error_msg}"

          # Provide more context for common errors
          if error_msg.include?('timeout') || error_msg.include?('Connection reset')
            puts "  ❌ Error: #{error_msg}"
            puts "     💡 La conexión con Facebook API fue interrumpida. Los reintentos ya se intentaron."
            puts "     💡 Puede reintentar esta página más tarde con: rake facebook:fanpage_crawler[1]"
          elsif error_msg.include?('authentication')
            puts "  ❌ Error: #{error_msg}"
            puts "     💡 Verifica que FACEBOOK_API_TOKEN esté configurado correctamente"
          else
            puts "  ❌ Error: #{error_msg}"
          end
          break
        end

        data = response.data || {}
        entries = Array(data[:entries]).compact

        if entries.empty?
          puts "  ⚠️  No entries returned"
        else
          entries.each do |facebook_entry|
            tag_info = facebook_entry.tags.any? ? " [#{facebook_entry.tag_list.join(', ')}]" : " [No tags]"
            link_info = facebook_entry.entry.present? ? " [→ Entry #{facebook_entry.entry_id}]" : ""
            puts "    ✓ #{facebook_entry.facebook_post_id} (#{facebook_entry.posted_at.strftime('%Y-%m-%d')})#{link_info}#{tag_info}"
          end
          puts "  ✓ Stored #{entries.size} posts"
        end

        cursor = data[:next]
        break if cursor.blank?
        break if page_count >= max_pages

        # Small delay between pages to avoid rate limits
        sleep(0.5) if cursor.present?
      end

      puts "  ✓ Completed: #{page_count} pages processed"
    end

    puts "\n" + "=" * 80
    puts "CRAWL COMPLETE"
    puts "=" * 80 + "\n"
  end
end

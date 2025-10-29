# frozen_string_literal: true

namespace :facebook do
  desc 'Facebook crawler'
  task fanpage_crawler: :environment do
    Page.find_each do |page|
      cursor = nil
      iteration = 1

      loop do
        label = cursor.present? ? "cursor: #{cursor}" : "page: #{iteration}"
        puts "Process Fanpage: #{page.name}, #{label}"

        response = FacebookServices::FanpageCrawler.call(page.uid, cursor)
        unless response.success?
          puts "  -> Error crawling #{page.name}: #{response.error}"
          break
        end
        data = response.data || {}
        entries = Array(data[:entries]).compact

        if entries.empty?
          puts "  -> No entries returned for #{page.name}"
        else
          entries.each do |facebook_entry|
            tag_info = facebook_entry.tags.any? ? " [Tags: #{facebook_entry.tag_list.join(', ')}]" : " [No tags]"
            puts "  -> Stored Facebook post #{facebook_entry.facebook_post_id} (posted at #{facebook_entry.posted_at})#{tag_info}"
          end
        end

        cursor = data[:next]
        break if cursor.blank?
        break if iteration >= 2

        iteration += 1
      end
    end
  end
end

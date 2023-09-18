# frozen_string_literal: true

namespace :facebook do
  desc 'Facebook crawler'
  task fanpage_crawler: :environment do
    pages = Page.where.not(uid: nil)
    # pages = Page.where(id: 8)
    pages.each do |page|
      puts "Process Fanpage: #{page.name}, page: 1"
      response = FacebookServices::FanpageCrawler.call(page.uid)

      posts = response.data[:posts]
      posts.each do |k, v|
        entry = Entry.find_by(url: v)
        if entry
          entry.update!(uid: k)
          puts "Found: #{v}"
        else
          puts "Not found: #{v}"
          WebExtractorServices::UrlCrawler.call(v, page.site, k)
        end
      end

      next if response.data[:next].nil?

      puts "Process Fanpage: #{page.name}, page: 2"
      response = FacebookServices::FanpageCrawler.call(page.uid, response.data[:next])
      break if response.data[:next].nil?

      posts = response.data[:posts]
      posts.each do |k, v|
        entry = Entry.find_by(url: v)
        if entry
          entry.update!(uid: k)
          puts "Found: #{v}"
        else
          puts "Not found: #{v}"
          WebExtractorServices::UrlCrawler.call(v, page.site, k)
        end
      end
    end
  end
end

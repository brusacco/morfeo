# frozen_string_literal: true

require 'nokogiri'
require 'open-uri'
require 'parallel'

# List of site IDs to ignore completely
IGNORED_SITE_IDS = [142].freeze

desc 'Crawl URLs from unlinked social media posts (Twitter and Facebook) and link them to entries'
task social_crawler: :environment do
  puts '=' * 80
  puts 'SOCIAL MEDIA CRAWLER'
  puts '=' * 80
  puts "Started at: #{Time.current}"
  puts ''

  # Statistics
  stats = {
    twitter_processed: 0,
    twitter_linked: 0,
    twitter_created: 0,
    twitter_skipped: 0,
    facebook_processed: 0,
    facebook_linked: 0,
    facebook_created: 0,
    facebook_skipped: 0,
    errors: 0
  }

  #------------------------------------------------------------------------------
  # Process Twitter Posts
  #------------------------------------------------------------------------------
  puts '📱 Processing Twitter Posts...'
  puts '-' * 80

  # Find Twitter posts of type "Link" without an associated entry
  twitter_posts = TwitterPost.where(entry_id: nil)
                             .where.not(payload: nil)
                             .where('LENGTH(payload) > 10')
                             .order(created_at: :desc)

  puts "Found #{twitter_posts.count} unlinked Twitter posts to process"
  puts ''

  Parallel.each(twitter_posts, in_threads: 5) do |post|
    ActiveRecord::Base.connection_pool.with_connection do
      # Extract URL from post
      url = extract_twitter_url(post)

      if url.blank?
        stats[:twitter_skipped] += 1
        next
      end

      # Normalize URL
      url = normalize_url(url)

      puts ''
      puts "[TWITTER] Processing: #{url}"

      # Find associated site
      site = find_site_for_url(url)

      unless site
        puts '  → No site found for URL'
        stats[:twitter_skipped] += 1
        next
      end

      puts "  → Site: #{site.name}"

      # Check if site is in ignored list
      if IGNORED_SITE_IDS.include?(site.id)
        puts "  → Skipping: Site is in ignored list (ID: #{site.id})"
        stats[:twitter_skipped] += 1
        next
      end

      # Check if site is disabled
      unless site.status
        puts "  → Skipping: Site is disabled (ID: #{site.id})"
        stats[:twitter_skipped] += 1
        next
      end

      # Apply URL filters
      unless url_matches_site_filters?(url, site)
        stats[:twitter_skipped] += 1
        next
      end

      # Check if entry already exists
      existing_entry = Entry.find_by(url: url)

      if existing_entry
        puts "  ✓ Entry already exists (ID: #{existing_entry.id})"
        post.update!(entry: existing_entry)
        puts '  ✓ Linked twitter post to existing entry'
        stats[:twitter_linked] += 1
        stats[:twitter_processed] += 1
        next
      end

      # Fetch and process the URL
      puts '  → Fetching content...'
      doc = fetch_page(url, site)

      unless doc
        puts '  ✗ Failed to fetch content'
        stats[:errors] += 1
        next
      end

      # Create entry
      entry = Entry.create!(url: url, site: site)
      puts "  ✓ Created entry (ID: #{entry.id})"

      # Extract basic info
      result = WebExtractorServices::ExtractBasicInfo.call(doc)
      if result.success?
        entry.update!(result.data)
        puts "  ✓ Basic info extracted: #{entry.title&.truncate(60)}"
      else
        puts "  ✗ ERROR BASIC: #{result.error}"
      end

      # Extract content
      if site.content_filter.present?
        result = WebExtractorServices::ExtractContent.call(doc, site.content_filter)
        if result.success?
          entry.update!(result.data)
          puts "  ✓ Content extracted (#{result.data[:content]&.length} chars)"
        else
          puts "  ✗ ERROR CONTENT: #{result.error}"
        end
      end

      # Extract date
      result = WebExtractorServices::ExtractDate.call(doc)
      if result.success?
        entry.update!(result.data)
        puts "  ✓ Date extracted: #{result.published_at}"
      else
        puts "  ✗ ERROR DATE: #{result.error}"
      end

      # Extract tags
      result = WebExtractorServices::ExtractTags.call(entry.id)
      if result.success?
        entry.tag_list.add(result.data)
        entry.save!
        tags = result.data.is_a?(Array) ? result.data : [result.data]
        puts "  ✓ Tags extracted: #{tags.join(', ')}"
      else
        puts "  ✗ ERROR TAGGER: #{result.error}"
      end

      # Extract title tags
      result = WebExtractorServices::ExtractTitleTags.call(entry.id)
      if result.success?
        entry.tag_list.add(result.data)
        entry.save!
        tags = result.data.is_a?(Array) ? result.data : [result.data]
        puts "  ✓ Title tags extracted: #{tags.join(', ')}"
      else
        puts "  ✗ ERROR TITLE TAGGER: #{result.error}"
      end

      # Update Facebook stats
      result = FacebookServices::UpdateStats.call(entry.id)
      if result.success?
        entry.update!(result.data)
        puts '  ✓ Stats updated'
      end

      # Link post to entry
      post.update!(entry: entry)
      puts '  ✓ Linked twitter post to entry'

      stats[:twitter_created] += 1
      stats[:twitter_processed] += 1
      puts '  ✅ Successfully processed!'
    rescue StandardError => e
      puts "  ✗ ERROR: #{e.message}"
      puts "  #{e.backtrace.first(3).join("\n  ")}"
      stats[:errors] += 1
    end
  end

  puts ''
  puts '=' * 80

  #------------------------------------------------------------------------------
  # Process Facebook Posts
  #------------------------------------------------------------------------------
  puts '📘 Processing Facebook Posts...'
  puts '-' * 80

  # Find Facebook posts of type "Link" without an associated entry
  facebook_posts = FacebookEntry.where(entry_id: nil)
                                .where(attachment_type: 'share')
                                .where.not(attachment_url: nil)
                                .order(created_at: :desc)

  puts "Found #{facebook_posts.count} unlinked Facebook posts to process"
  puts ''

  Parallel.each(facebook_posts, in_threads: 5) do |post|
    ActiveRecord::Base.connection_pool.with_connection do
      url = post.attachment_url

      if url.blank?
        stats[:facebook_skipped] += 1
        next
      end

      # Normalize URL
      url = normalize_url(url)

      puts ''
      puts "[FACEBOOK] Processing: #{url}"

      # Get site from Facebook post's page (if available)
      post_site = post.page&.site
      puts "  → Post from Facebook page: #{post.page.name} (Site: #{post_site.name})" if post_site

      # Find associated site from URL
      url_site = find_site_for_url(url)

      unless url_site
        puts '  → No site found for URL'
        stats[:facebook_skipped] += 1
        next
      end

      # Use site from URL (the actual content source)
      # If post site matches URL site, that's ideal, but URL site takes precedence
      site = url_site

      if post_site && post_site.id != site.id
        puts "  ⚠ Post from #{post_site.name} but URL is from #{site.name} - using #{site.name}"
      end

      puts "  → Site: #{site.name}"

      # Check if site is in ignored list
      if IGNORED_SITE_IDS.include?(site.id)
        puts "  → Skipping: Site is in ignored list (ID: #{site.id})"
        stats[:facebook_skipped] += 1
        next
      end

      # Check if site is disabled
      unless site.status
        puts "  → Skipping: Site is disabled (ID: #{site.id})"
        stats[:facebook_skipped] += 1
        next
      end

      # Apply URL filters
      unless url_matches_site_filters?(url, site)
        stats[:facebook_skipped] += 1
        next
      end

      # Check if entry already exists
      existing_entry = Entry.find_by(url: url)

      if existing_entry
        puts "  ✓ Entry already exists (ID: #{existing_entry.id})"
        post.update!(entry: existing_entry)
        puts '  ✓ Linked facebook post to existing entry'
        stats[:facebook_linked] += 1
        stats[:facebook_processed] += 1
        next
      end

      # Fetch and process the URL
      puts '  → Fetching content...'
      doc = fetch_page(url, site)

      unless doc
        puts '  ✗ Failed to fetch content'
        stats[:errors] += 1
        next
      end

      # Create entry
      entry = Entry.create!(url: url, site: site)
      puts "  ✓ Created entry (ID: #{entry.id})"

      # Extract basic info
      result = WebExtractorServices::ExtractBasicInfo.call(doc)
      if result.success?
        entry.update!(result.data)
        puts "  ✓ Basic info extracted: #{entry.title&.truncate(60)}"
      else
        puts "  ✗ ERROR BASIC: #{result.error}"
      end

      # Extract content
      if site.content_filter.present?
        result = WebExtractorServices::ExtractContent.call(doc, site.content_filter)
        if result.success?
          entry.update!(result.data)
          puts "  ✓ Content extracted (#{result.data[:content]&.length} chars)"
        else
          puts "  ✗ ERROR CONTENT: #{result.error}"
        end
      end

      # Extract date
      result = WebExtractorServices::ExtractDate.call(doc)
      if result.success?
        entry.update!(result.data)
        puts "  ✓ Date extracted: #{result.published_at}"
      else
        puts "  ✗ ERROR DATE: #{result.error}"
      end

      # Extract tags
      result = WebExtractorServices::ExtractTags.call(entry.id)
      if result.success?
        entry.tag_list.add(result.data)
        entry.save!
        tags = result.data.is_a?(Array) ? result.data : [result.data]
        puts "  ✓ Tags extracted: #{tags.join(', ')}"
      else
        puts "  ✗ ERROR TAGGER: #{result.error}"
      end

      # Extract title tags
      result = WebExtractorServices::ExtractTitleTags.call(entry.id)
      if result.success?
        entry.tag_list.add(result.data)
        entry.save!
        tags = result.data.is_a?(Array) ? result.data : [result.data]
        puts "  ✓ Title tags extracted: #{tags.join(', ')}"
      else
        puts "  ✗ ERROR TITLE TAGGER: #{result.error}"
      end

      # Update Facebook stats
      result = FacebookServices::UpdateStats.call(entry.id)
      if result.success?
        entry.update!(result.data)
        puts '  ✓ Stats updated'
      end

      # Link post to entry
      post.update!(entry: entry)
      puts '  ✓ Linked facebook post to entry'

      # Track cross-site sharing
      puts "  📊 Cross-site share detected: #{post_site.name} → #{site.name}" if post_site && post_site.id != site.id

      stats[:facebook_created] += 1
      stats[:facebook_processed] += 1
      puts '  ✅ Successfully processed!'
    rescue StandardError => e
      puts "  ✗ ERROR: #{e.message}"
      puts "  #{e.backtrace.first(3).join("\n  ")}"
      stats[:errors] += 1
    end
  end

  #------------------------------------------------------------------------------
  # Final Statistics
  #------------------------------------------------------------------------------
  puts ''
  puts '=' * 80
  puts 'SUMMARY'
  puts '=' * 80
  puts 'Twitter Posts:'
  puts "  - Processed: #{stats[:twitter_processed]}"
  puts "  - Linked to existing: #{stats[:twitter_linked]}"
  puts "  - New entries created: #{stats[:twitter_created]}"
  puts "  - Skipped: #{stats[:twitter_skipped]}"
  puts ''
  puts 'Facebook Posts:'
  puts "  - Processed: #{stats[:facebook_processed]}"
  puts "  - Linked to existing: #{stats[:facebook_linked]}"
  puts "  - New entries created: #{stats[:facebook_created]}"
  puts "  - Skipped: #{stats[:facebook_skipped]}"
  puts ''
  puts "Total Errors: #{stats[:errors]}"
  puts ''
  puts "Finished at: #{Time.current}"
  puts '=' * 80
end

#------------------------------------------------------------------------------
# Helper Methods
#------------------------------------------------------------------------------

def extract_twitter_url(post)
  return unless post.payload.present?

  payload = JSON.parse(post.payload)

  # Look for URLs in entities
  urls = payload.dig('legacy', 'entities', 'urls') || []

  # Return the first expanded URL
  urls.first&.dig('expanded_url')
rescue JSON::ParserError, StandardError
  nil
end

def normalize_url(url)
  return if url.blank?

  # Parse and normalize the URL
  uri = URI.parse(url)

  # Remove common tracking parameters
  if uri.query
    params = URI.decode_www_form(uri.query)
    # Remove fbclid, utm_*, gclid, etc.
    params.reject! { |k, _v| k =~ /^(fbclid|utm_|gclid|_ga)/ }
    uri.query = params.empty? ? nil : URI.encode_www_form(params)
  end

  # Rebuild URL
  uri.to_s
rescue URI::InvalidURIError, StandardError
  url
end

def find_site_for_url(url)
  return if url.blank?

  uri = URI.parse(url)
  target_domain = uri.host&.downcase

  return if target_domain.blank?

  # Find site by comparing exact domains from site.url field
  Site.all.find do |s|
    next false if s.url.blank?

    begin
      site_uri = URI.parse(s.url)
      site_domain = site_uri.host&.downcase
      next false if site_domain.blank?

      # Exact domain match only
      site_domain == target_domain
    rescue URI::InvalidURIError
      false
    end
  end
rescue URI::InvalidURIError, StandardError => e
  puts "  ⚠ Error finding site for URL: #{e.message}"
  nil
end

def url_matches_site_filters?(url, site)
  return false unless url.present? && site.present?

  begin
    # Check for unwanted file extensions
    unwanted_extensions = /.*\.(jpeg|jpg|gif|png|pdf|mp3|mp4|mpeg|zip|rar|exe|dmg)$/i
    if url.match?(unwanted_extensions)
      puts '  → Skipping: Unwanted file extension'
      return false
    end

    # Check for unwanted directories
    # Only match complete directory segments (surrounded by / or at start/end)
    unwanted_directories = %w[
      blackhole
      wp-login
      wp-admin
      galerias
      fotoblog
      radios
      page
      etiqueta
      categoria
      category
      pagina
      auth
      wp-content
      img
      tag
      contacto
      programa
      date
      feed
      author
    ]
    # Match directories as complete path segments: /directory/ or /directory or directory/
    directory_pattern = %r{(?:/|^)(?:#{unwanted_directories.join('|')})(?:/|$)}i
    if url.match?(directory_pattern)
      puts '  → Skipping: Contains unwanted directory'
      return false
    end

    # Check positive filter (if exists)
    if site.filter.present?
      filter_regex = Regexp.new(site.filter)
      unless url.match?(filter_regex)
        puts "  → Skipping: Does not match site's positive filter (#{site.filter})"
        return false
      end
    end

    # Check negative filter (if exists)
    if site.negative_filter.present?
      negative_regex = Regexp.new(site.negative_filter)
      if url.match?(negative_regex)
        puts "  → Skipping: Matches site's negative filter (#{site.negative_filter})"
        return false
      end
    end

    true
  rescue StandardError => e
    puts "  ⚠ Error validating URL filters: #{e.message}"
    false
  end
end

def fetch_page(url, site = nil)
  return if url.blank?

  # If site requires JavaScript, use proxy directly
  if site&.is_js?
    puts '  → Site requires JS, using scrape.do proxy...'
    return fetch_via_proxy(url, site)
  end

  # Try normal fetch first
  begin
    response = URI.parse(url).open(
      'User-Agent' => 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36'
    )

    Nokogiri::HTML(response.read.force_encoding('UTF-8'))
  rescue OpenURI::HTTPError => e
    # If we get 403 Forbidden, try proxy (site might be protected)
    http_code =
      begin
        e.io.status[0].to_i
      rescue StandardError
        nil
      end
    if http_code == 403 || e.message.include?('403')
      puts '  ⚠ Got 403 Forbidden, retrying with scrape.do proxy...'
      return fetch_via_proxy(url, site)
    end

    puts "  ⚠ Fetch error: #{e.message}"
    nil
  rescue StandardError => e
    puts "  ⚠ Fetch error: #{e.message}"
    nil
  end
end

def fetch_via_proxy(url, site = nil)
  proxy_client = ProxyCrawlerServices::ProxyClient.new

  # Use site's content_filter as waitSelector if available
  wait_selector = site&.content_filter.present? ? site.content_filter : nil

  puts "  → Using waitSelector: #{wait_selector}" if wait_selector.present?

  response = proxy_client.fetch(url, wait_selector: wait_selector)

  unless response.success?
    puts "  ⚠ Proxy fetch error: #{response.error}"
    return
  end

  puts "  ✓ Successfully fetched via proxy (#{response.body.size} bytes)"
  Nokogiri::HTML(response.body.force_encoding('UTF-8'))
rescue StandardError => e
  puts "  ⚠ Proxy error: #{e.message}"
  nil
end

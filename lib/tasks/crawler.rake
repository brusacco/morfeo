# frozen_string_literal: true

# ============================================================================
# CRAWLER CONSTANTS
# ============================================================================
module CrawlerConstants
  BINARY_FILE_EXTENSIONS = /.*\.(jpeg|jpg|gif|png|pdf|mp3|mp4|mpeg)/

  EXCLUDED_DIRECTORIES = %w[
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
  ].freeze

  # Regex that never matches (Spanish "never") - used when site has no negative filter
  DEFAULT_NEGATIVE_FILTER = 'NUNCA'

  # Pre-compile directory exclusion pattern
  DIRECTORY_PATTERN = Regexp.new(EXCLUDED_DIRECTORIES.join('|')).freeze
end

desc 'Moopio Morfeo web crawler - Production-optimized version'
task :crawler, [:depth] => :environment do |_t, args|
  include CrawlerConstants

  # Parse depth argument (default: 2, deep crawl: 3)
  depth_limit = (args[:depth] || 2).to_i

  # Validate depth (1-5 range)
  unless (1..5).include?(depth_limit)
    Rails.logger.error "Invalid depth: #{depth_limit}. Must be between 1 and 5."
    exit 1
  end

  # ============================================================================
  # MAIN CRAWLER LOOP
  # ============================================================================
  Rails.logger.info '=' * 80
  Rails.logger.info 'Starting Morfeo Web Crawler'
  Rails.logger.info "Depth Limit: #{depth_limit} (#{depth_limit == 3 ? 'DEEP CRAWL' : 'standard'})"
  Rails.logger.info "Time: #{Time.current}"
  Rails.logger.info "Database Pool Size: #{ActiveRecord::Base.connection_pool.size}"
  Rails.logger.info '=' * 80

  # CRITICAL: Load sites into array first to release connection
  # Using find_each holds a connection for the entire loop
  sites_to_crawl = Site.enabled.where(is_js: false).order(total_count: :desc).to_a

  if sites_to_crawl.empty?
    Rails.logger.warn 'No enabled sites found to crawl'
    exit 0
  end

  Rails.logger.info "Found #{sites_to_crawl.count} sites to crawl"

  overall_start = Time.current
  total_sites = 0
  total_entries = 0
  total_errors = 0

  sites_to_crawl.each do |site|
    total_sites += 1
    Rails.logger.info "\n#{'=' * 70}"
    Rails.logger.info "Site #{total_sites}: #{site.name}"
    Rails.logger.info "URL: #{site.url}"
    Rails.logger.info "Filter: #{site.filter}"
    Rails.logger.info "#{'=' * 70}"

    site_start_time = Time.current
    processed_count = 0
    error_count = 0
    skipped_count = 0

     # ------------------------------------------------------------------------
     # STATS: Count existing entries for this site
     # ------------------------------------------------------------------------
     Rails.logger.info 'URL column has unique index - lookups are O(log n) fast'

    # ------------------------------------------------------------------------
    # OPTIMIZATION 2: Pre-compile site-specific regexes
    # ------------------------------------------------------------------------
    # Safely compile filter regex with error handling
    begin
      filter_pattern = Regexp.new(site.filter)
    rescue RegexpError => e
      Rails.logger.error "Invalid filter regex for #{site.name}: #{site.filter}"
      Rails.logger.error "RegexpError: #{e.message}"
      error_count += 1
      next # Skip this site
    end

    # Safely compile negative filter regex with fallback
    negative_filter_pattern =
      begin
        if site.negative_filter.present?
          Regexp.new(site.negative_filter)
        else
          Regexp.new(DEFAULT_NEGATIVE_FILTER)
        end
      rescue RegexpError => e
        Rails.logger.warn "Invalid negative filter regex for #{site.name}, using default: #{e.message}"
        Regexp.new(DEFAULT_NEGATIVE_FILTER)
      end

    # ------------------------------------------------------------------------
    # OPTIMIZATION 3: Ensure thread safety with connection pool
    # ------------------------------------------------------------------------
    # CRITICAL: max_threads must be LESS than connection pool size
    # Otherwise you get deadlocks when all threads wait for connections
    pool_size = ActiveRecord::Base.connection_pool.size

    # Start conservative - use only 2 threads until pool size is confirmed working
    # Formula: pool_size must be >= (threads + 5 for overhead)
    # With pool=20: safe to use up to 15 threads, but 5 is optimal
    max_threads =
      if pool_size >= 15
        5 # Optimal for speed/stability balance
      elsif pool_size >= 10
        3  # Conservative for smaller pools
      elsif pool_size >= 7
        2  # Very conservative
      else
        1  # Sequential processing only
      end

    Rails.logger.info "Using #{max_threads} threads (DB pool size: #{pool_size})"

    if pool_size < 7
      Rails.logger.warn "⚠️  WARNING: Connection pool size (#{pool_size}) is very small!"
      Rails.logger.warn '⚠️  Increase pool in config/database.yml to at least 20'
      Rails.logger.warn '⚠️  Then restart Rails to apply changes'
    end

     # ------------------------------------------------------------------------
     # ANEMONE CRAWLER CONFIGURATION
     # ------------------------------------------------------------------------
     Anemone.crawl(
       site.url,
       read_timeout: 10,
       depth_limit: depth_limit,  # Configurable depth (2 or 3)
       discard_page_bodies: true,
       accept_cookies: true,
       threads: max_threads,
       # delay: 0.5, # Polite crawling: 500ms delay prevents rate limiting & server overload
       verbose: false, # Use Rails logger instead of Anemone's output
       user_agent: 'Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/62.0.3115 Safari/537.36'
     ) do |anemone|
      # Skip binary files and excluded directories
      anemone.skip_links_like(BINARY_FILE_EXTENSIONS, DIRECTORY_PATTERN)

      # ------------------------------------------------------------------------
      # FOCUS CRAWL: Filter links before processing
      # ------------------------------------------------------------------------
      anemone.focus_crawl do |page|
        # Apply negative filter (if configured) to skip unwanted URLs
        page.links.delete_if { |href| href.to_s.match(negative_filter_pattern) }

        # NOTE: We don't check Entry.exists? here to avoid N+1 queries
        # Instead, we rely on:
        # 1. find_or_initialize_by which uses the indexed URL lookup (very fast)
        # 2. Anemone's built-in duplicate URL tracking within the crawl session
        # 3. The 'skipped_count' tracking in on_pages_like to monitor duplicates
      end

       # ------------------------------------------------------------------------
       # PROCESS MATCHING PAGES
       # ------------------------------------------------------------------------
       anemone.on_pages_like(filter_pattern) do |page|
         # ------------------------------------------------------------------------
         # FIND OR INITIALIZE ENTRY
         # ------------------------------------------------------------------------
         # This is efficient because:
         # 1. URL has a unique index (O(log n) lookup, not O(n))
         # 2. For 100K entries, indexed lookup takes ~17 comparisons vs 100K
         # 3. Database is optimized for this exact use case
         entry = Entry.find_or_initialize_by(url: page.url.to_s)

         is_new_entry = entry.new_record?

         if entry.persisted?
           # Entry already exists - skip basic data extraction but RE-TAG
           Rails.logger.debug { "Re-tagging existing entry: #{entry.url}" }
           skipped_count += 1
           # Don't skip completely - fall through to re-run taggers below
         else
           entry.site = site
           Rails.logger.info "\n[#{processed_count + 1}] Processing NEW entry: #{entry.url}"
         end

         # ------------------------------------------------------------------------
         # BASIC DATA EXTRACTION (only for new entries)
         # ------------------------------------------------------------------------
         if is_new_entry
           entry_data = {}

           # Extract basic info (title, description, image)
           result = WebExtractorServices::ExtractBasicInfo.call(page.doc)
           if result.success?
             entry_data.merge!(result.data)
             Rails.logger.debug '  ✓ Basic info extracted'
           else
             Rails.logger.warn "  ✗ Basic extraction failed: #{result.error}"
           end

           # Extract content (if site has content filter configured)
           if site.content_filter.present?
             result = WebExtractorServices::ExtractContent.call(page.doc, site.content_filter)
             if result.success?
               entry_data.merge!(result.data)
               Rails.logger.debug '  ✓ Content extracted'
             else
               Rails.logger.warn "  ✗ Content extraction failed: #{result.error}"
             end
           end

           # Extract publication date
           result = WebExtractorServices::ExtractDate.call(page.doc)
           if result.success?
             entry_data.merge!(result.data)
             Rails.logger.debug { "  ✓ Date extracted: #{result.data[:published_at]}" }
           else
             Rails.logger.warn "  ✗ Date extraction failed: #{result.error}"
           end

           # ------------------------------------------------------------------------
           # SAVE BASIC DATA (only for new entries)
           # ------------------------------------------------------------------------
           entry.assign_attributes(entry_data)

           # Don't save if we got no useful data (all extractors failed)
           if entry_data.empty? || entry.title.blank?
             Rails.logger.warn '  ✗ Skipping entry - no data extracted (title is blank)'
             skipped_count += 1
             next
           end

           # Transaction wrapper for data integrity
           ActiveRecord::Base.transaction do
             entry.save!
             Rails.logger.info "  ✓ Entry saved (ID: #{entry.id})"
           end

           processed_count += 1
         end

        # ------------------------------------------------------------------------
        # TAG EXTRACTION (ALWAYS RUN - even for existing entries)
        # ------------------------------------------------------------------------
        # This ensures:
        # - New tags added to system are applied to old entries
        # - Tag variations updates are picked up
        # - Improved tagging logic benefits existing content
        tag_data_changed = false

        # Extract regular tags (body + title + description)
        result = WebExtractorServices::ExtractTags.call(entry.id)
        if result.success?
          # Only update if tags actually changed (avoid unnecessary DB writes)
          new_tags = result.data.sort
          current_tags = entry.tag_list.sort

          if new_tags != current_tags
            entry.tag_list = result.data
            tag_data_changed = true
            Rails.logger.debug { "  ✓ Tags updated: #{result.data.join(', ')}" }
          else
            Rails.logger.debug { "  ✓ Tags unchanged: #{result.data.join(', ')}" }
          end
        else
          Rails.logger.warn "  ✗ Tag extraction failed: #{result.error}"
        end

        # Extract title-only tags
        result = WebExtractorServices::ExtractTitleTags.call(entry.id)
        if result.success?
          # Only update if title tags actually changed
          new_title_tags = result.data.sort
          current_title_tags = entry.title_tag_list.sort

          if new_title_tags != current_title_tags
            entry.title_tag_list = result.data
            tag_data_changed = true
            Rails.logger.debug { "  ✓ Title tags updated: #{result.data.join(', ')}" }
          else
            Rails.logger.debug { "  ✓ Title tags unchanged: #{result.data.join(', ')}" }
          end
        else
          Rails.logger.warn "  ✗ Title tag extraction failed: #{result.error}"
        end

        # Save tags ONLY if something actually changed
        if tag_data_changed
          ActiveRecord::Base.transaction do
            entry.save!
            Rails.logger.debug '  ✓ Tags saved and topics synced'
          end
        else
          Rails.logger.debug '  ✓ No tag changes - skipping save'
        end

         # ------------------------------------------------------------------------
         # ASYNC JOBS (only for new entries to avoid spam)
         # ------------------------------------------------------------------------
         if is_new_entry
           # Queue Facebook stats update (API call, can be slow)
           UpdateEntryFacebookStatsJob.perform_later(entry.id)
           Rails.logger.debug '  ⏱ Facebook stats queued'

           # Queue sentiment analysis (OpenAI API call with 5s sleep, very slow)
           if entry.belongs_to_any_topic?
             SetEntrySentimentJob.perform_later(entry.id)
             Rails.logger.debug '  ⏱ Sentiment analysis queued'
           end
         end

        # Progress logging every 10 entries
        if processed_count % 10 == 0
          elapsed = Time.current - site_start_time
          # Guard against division by zero
          rate = elapsed.positive? ? (processed_count / elapsed) : 0
          Rails.logger.info "\nProgress: #{processed_count} entries processed, #{skipped_count} skipped (#{rate.round(2)} entries/sec)"
        end
      rescue ActiveRecord::RecordInvalid, ActiveRecord::RecordNotUnique => e
        # Handle duplicate entries or validation errors
        error_count += 1
        total_errors += 1
        Rails.logger.error "  ✗ Failed to save entry: #{e.message}"
        Rails.logger.error "  URL: #{page.url}"
        next
      rescue StandardError => e
        # Handle unexpected errors
        error_count += 1
        total_errors += 1
        Rails.logger.error "  ✗ Unexpected error: #{e.class} - #{e.message}"
        Rails.logger.error "  URL: #{page.url}"
        Rails.logger.error "  Backtrace: #{e.backtrace.first(3).join("\n  ")}"

        # Re-raise critical errors (don't silently swallow them)
        raise if e.is_a?(ActiveRecord::ConnectionNotEstablished)

        next
      end
    end

    # ------------------------------------------------------------------------
    # SITE COMPLETION SUMMARY
    # ------------------------------------------------------------------------
    site_elapsed = Time.current - site_start_time
    total_entries += processed_count

    Rails.logger.info "\n#{'=' * 70}"
    Rails.logger.info "Site Completed: #{site.name}"
    Rails.logger.info "  New Entries: #{processed_count}"
    Rails.logger.info "  Skipped: #{skipped_count}"
    Rails.logger.info "  Errors: #{error_count}"
    Rails.logger.info "  Time: #{site_elapsed.round(2)}s"
    # Guard against division by zero
    if processed_count.positive? && site_elapsed.positive?
      Rails.logger.info "  Rate: #{(processed_count / site_elapsed).round(2)} entries/sec"
    end
    Rails.logger.info "#{'=' * 70}"
  rescue StandardError => e
    # Handle site-level errors (e.g., DNS failure, connection timeout)
    total_errors += 1
    Rails.logger.error "\n#{'!' * 70}"
    Rails.logger.error "SITE FAILED: #{site.name}"
    Rails.logger.error "Error: #{e.class} - #{e.message}"
    Rails.logger.error "Backtrace:\n  #{e.backtrace.first(5).join("\n  ")}"
    Rails.logger.error "#{'!' * 70}"
    next # Continue to next site
  end

  # ============================================================================
  # OVERALL COMPLETION SUMMARY
  # ============================================================================
  overall_elapsed = Time.current - overall_start

  Rails.logger.info "\n#{'=' * 80}"
  Rails.logger.info 'CRAWLER COMPLETED'
  Rails.logger.info "#{'=' * 80}"
  Rails.logger.info "Sites Processed: #{total_sites}"
  Rails.logger.info "Total New Entries: #{total_entries}"
  Rails.logger.info "Total Errors: #{total_errors}"
  Rails.logger.info "Total Time: #{overall_elapsed.round(2)}s (#{(overall_elapsed / 60).round(2)} minutes)"
  # Guard against division by zero
  if total_entries.positive? && overall_elapsed.positive?
    Rails.logger.info "Average Rate: #{(total_entries / overall_elapsed).round(2)} entries/sec"
  end
  Rails.logger.info "Time: #{Time.current}"
  Rails.logger.info "#{'=' * 80}"
end

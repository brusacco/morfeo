# frozen_string_literal: true

class BackfillEntryTopicsJob < ApplicationJob
  queue_as :default

  def perform(batch_size: 500, start_id: nil, end_id: nil)
    start_time = Time.current
    total_entries = Entry.count
    processed = 0
    skipped = 0
    errors = []

    Rails.logger.info "=" * 80
    Rails.logger.info "Starting Entry-Topic backfill"
    Rails.logger.info "Total entries: #{total_entries}"
    Rails.logger.info "Batch size: #{batch_size}"
    Rails.logger.info "Start ID: #{start_id || 'beginning'}"
    Rails.logger.info "End ID: #{end_id || 'end'}"
    Rails.logger.info "=" * 80

    # Build query
    query = Entry.order(:id)
    query = query.where('id >= ?', start_id) if start_id
    query = query.where('id <= ?', end_id) if end_id

    # Process in batches
    query.find_in_batches(batch_size: batch_size) do |batch|
      batch.each do |entry|
        begin
          # Sync both tag types
          synced_tags = sync_entry_tags(entry)
          synced_title_tags = sync_entry_title_tags(entry)

          processed += 1

          # Log progress every 100 entries
          if processed % 100 == 0
            elapsed = Time.current - start_time
            rate = processed / elapsed
            remaining = (total_entries - processed) / rate

            Rails.logger.info "[#{processed}/#{total_entries}] " \
                            "Rate: #{rate.round(1)}/sec | " \
                            "ETA: #{remaining.to_i}sec | " \
                            "Entry #{entry.id}: #{synced_tags} tags, #{synced_title_tags} title tags"
          end
        rescue => e
          errors << {
            entry_id: entry.id,
            error: e.message,
            backtrace: e.backtrace.first(3)
          }
          Rails.logger.error "Entry #{entry.id} FAILED: #{e.message}"
          skipped += 1
        end
      end

      # Throttle to avoid overwhelming database
      sleep 0.05
    end

    # Final report
    duration = Time.current - start_time
    Rails.logger.info "=" * 80
    Rails.logger.info "Backfill complete!"
    Rails.logger.info "Duration: #{duration.round(2)}s"
    Rails.logger.info "Processed: #{processed}"
    Rails.logger.info "Skipped: #{skipped}"
    Rails.logger.info "Errors: #{errors.size}"
    Rails.logger.info "Rate: #{(processed / duration).round(2)} entries/sec"
    Rails.logger.info "=" * 80

    if errors.any?
      Rails.logger.error "Errors encountered:"
      errors.each do |err|
        Rails.logger.error "  Entry #{err[:entry_id]}: #{err[:error]}"
      end
    end

    {
      processed: processed,
      skipped: skipped,
      errors: errors,
      duration: duration
    }
  end

  private

  def sync_entry_tags(entry)
    # Force reload tag_list from database
    entry.reload
    tags = entry.tag_list
    return 0 if tags.empty?

    matching_topics = Topic.joins(:tags)
                          .where(tags: { name: tags })
                          .distinct

    if matching_topics.any?
      entry.topics = matching_topics
      matching_topics.count
    else
      0
    end
  end

  def sync_entry_title_tags(entry)
    # Force reload title_tag_list from database
    entry.reload
    title_tags = entry.title_tag_list
    return 0 if title_tags.empty?

    matching_topics = Topic.joins(:tags)
                          .where(tags: { name: title_tags })
                          .distinct

    if matching_topics.any?
      entry.title_topics = matching_topics
      matching_topics.count
    else
      0
    end
  end
end


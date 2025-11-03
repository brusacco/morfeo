# frozen_string_literal: true

class SyncTopicEntriesJob < ApplicationJob
  queue_as :default

  def perform(topic_id, days = 60)
    topic = Topic.find_by(id: topic_id)
    
    return unless topic

    start_date = days.days.ago.beginning_of_day
    end_date = Time.current.end_of_day
    tag_names = topic.tags.pluck(:name)

    if tag_names.empty?
      Rails.logger.info "SyncTopicEntriesJob: Topic #{topic_id} has no tags, skipping"
      return
    end

    Rails.logger.info "SyncTopicEntriesJob: Starting sync for Topic #{topic_id} (#{topic.name}) - #{tag_names.size} tags, #{days} days"

    # Find all entries that match the topic's tags
    entries = Entry.enabled
                   .where(published_at: start_date..end_date)
                   .tagged_with(tag_names, any: true)
                   .distinct

    entries_count = entries.count('DISTINCT entries.id')

    if entries_count.zero?
      Rails.logger.info "SyncTopicEntriesJob: No entries found for Topic #{topic_id}"
      return
    end

    # Sync each entry
    synced = 0
    skipped = 0
    errors = 0

    entries.find_each do |entry|
      begin
        entry.sync_topics_from_tags
        synced += 1
      rescue => e
        Rails.logger.error "SyncTopicEntriesJob: Failed to sync Entry #{entry.id} - #{e.message}"
        errors += 1
      end
    end

    Rails.logger.info "SyncTopicEntriesJob: Completed for Topic #{topic_id} - Synced: #{synced}, Errors: #{errors}"

    {
      topic_id: topic_id,
      topic_name: topic.name,
      entries_found: entries_count,
      synced: synced,
      errors: errors
    }
  rescue => e
    Rails.logger.error "SyncTopicEntriesJob: Failed for Topic #{topic_id} - #{e.message}"
    Rails.logger.error e.backtrace.first(5).join("\n")
    raise
  end
end


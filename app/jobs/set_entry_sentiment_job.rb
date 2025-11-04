# frozen_string_literal: true

class SetEntrySentimentJob < ApplicationJob
  queue_as :default

  # Retry with exponential backoff for rate limiting
  retry_on StandardError, wait: :exponentially_longer, attempts: 3

  def perform(entry_id)
    entry = Entry.find(entry_id)

    # Only set polarity if entry belongs to a topic
    return unless entry.belongs_to_any_topic?

    entry.set_polarity(force: false)

    Rails.logger.info "SetEntrySentimentJob: Successfully set polarity for Entry #{entry_id}"
  rescue ActiveRecord::RecordNotFound
    Rails.logger.warn "SetEntrySentimentJob: Entry #{entry_id} not found, skipping"
  rescue StandardError => e
    Rails.logger.error "SetEntrySentimentJob: Failed for Entry #{entry_id}: #{e.message}"
    raise # Re-raise to trigger retry logic
  end
end

# frozen_string_literal: true

class UpdateEntryFacebookStatsJob < ApplicationJob
  queue_as :default

  # Retry with exponential backoff for API rate limiting
  retry_on StandardError, wait: :exponentially_longer, attempts: 3

  def perform(entry_id)
    entry = Entry.find(entry_id)

    result = FacebookServices::UpdateStats.call(entry_id)

    if result.success?
      entry.update!(result.data)
      Rails.logger.info "UpdateEntryFacebookStatsJob: Successfully updated stats for Entry #{entry_id}"
    else
      Rails.logger.error "UpdateEntryFacebookStatsJob: Failed for Entry #{entry_id}: #{result.error}"
    end
  rescue ActiveRecord::RecordNotFound
    Rails.logger.warn "UpdateEntryFacebookStatsJob: Entry #{entry_id} not found, skipping"
  rescue StandardError => e
    Rails.logger.error "UpdateEntryFacebookStatsJob: Failed for Entry #{entry_id}: #{e.message}"
    raise # Re-raise to trigger retry logic
  end
end

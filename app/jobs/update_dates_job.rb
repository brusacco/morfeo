# frozen_string_literal: true

class UpdateDatesJob < ApplicationJob
  queue_as :default

  def perform(entry_id)
    entry = Entry.find(entry_id)
    doc = Nokogiri::HTML(URI.parse(entry.url).open)
    result = WebExtractorServices::ExtractDate.call(doc)
    entry.update!(result.data) if result.success?
    Rails.logger.debug { "Update-date #{entry.url} - #{result.data}" }
  end
end

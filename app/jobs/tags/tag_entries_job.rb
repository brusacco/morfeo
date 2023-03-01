# frozen_string_literal: true

module Tags
  class TagEntriesJob < ApplicationJob
    queue_as :default

    def perform(tag_id, range)
      entries = Entry.where(published_at: range)
      entries.each do |entry|
        result = WebExtractorServices::ExtractTags.call(entry.id, tag_id)
        next unless result.success?

        entry.tag_list.add(result.data)
        entry.save!
        entry.touch
      rescue StandardError
        sleep 1
        retry
      end
    end
  end
end

# frozen_string_literal: true

module AppServices
  class TagEntries < ApplicationService
    def initialize(tag_id)
      @tag_id = tag_id
      @range = range
    end

    def call
      entries = Entry.where(published_at: @range)
      entries.each do |entry|
        result = WebExtractorServices::ExtractTags.call(entry.id, @tag_id)
        next unless result.success?

        entry.tag_list.add(result.data)
        entry.save!
      end
      handle_success("Finish tagging #{entries.size}")
    rescue StandardError => e
      handle_error(e.message)
    end
  end
end

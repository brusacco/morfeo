# frozen_string_literal: true

module AppServices
  class UpdateTagEntries < ApplicationService
    def initialize(tag_id)
      @tag_id = tag_id
    end

    def call
      tag = Tag.find(@tag_id)
      entries = Entry.tagged_with(tag.name)
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

# frozen_string_literal: true

module Tags
  class UpdateTagEntriesJob < ApplicationJob
    queue_as :default

    def perform(tag_id)
      @tag = Tag.find(tag_id)
      entries = Entry.tagged_with(@tag.name)
      entries.each do |entry|
        result = WebExtractorServices::ExtractTags.call(entry.id, @tag_id)
        next unless result.success?

        entry.tag_list.add(result.data)
        entry.save!
      end
    end
  end
end

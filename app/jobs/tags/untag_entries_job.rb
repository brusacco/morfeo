# frozen_string_literal: true

module Tags
  class UntagEntriesJob < ApplicationJob
    queue_as :default

    def perform(tag_id)
      @tag = Tag.find(tag_id)
      entries = Entry.tagged_with(@tag.name)
      entries.each do |entry|
        entry.tag_list.remove(@tag.name)
        entry.save!
      rescue StandardError
        sleep 1
        retry
      end
    end
  end
end

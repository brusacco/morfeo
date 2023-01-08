# frozen_string_literal: true

module Tags
  class TagEntriesJob < ApplicationJob
    queue_as :default

    def perform(tag_id, range)
      AppServices::TagEntries.call(tag_id, range)
    end
  end
end

# frozen_string_literal: true

module Tags
  class UpdateTagEntriesJob < ApplicationJob
    queue_as :default

    def perform(tag_id, range)
      AppServices::UpdateTagEntries.call(tag_id, range)
    end
  end
end

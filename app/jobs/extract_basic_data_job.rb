# frozen_string_literal: true

class ExtractBasicDataJob < ApplicationJob
  queue_as :default

  def perform(entry_id, page)
    WebExtractorServices::ExtractBasicInfo.call(entry_id, page)
  end
end

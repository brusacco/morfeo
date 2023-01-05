# frozen_string_literal: true

module WebExtractorServices
  class ExtractTags < ApplicationService
    def initialize(entry_id)
      @entry_id = entry_id
    end

    def call
      entry = Entry.find(@entry_id)
      content = "#{entry.title} #{entry.description}"
      tags_found = []

      Tag.all.each do |tag|
        tags_found << tag.name if content.include?(tag.name)
        if tag.variations
          alts = tag.variations.split(',')
          alts.each { |alt_tag| tags_found << tag.name if content.include?(alt_tag) }
        end
      end

      if tags_found.empty?
        handle_error('No tags found')
      else
        handle_success(tags_found)
      end
    rescue StandardError => e
      handle_error(e.message)
    end
  end
end

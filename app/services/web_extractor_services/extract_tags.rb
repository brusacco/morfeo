# frozen_string_literal: true

module WebExtractorServices
  class ExtractTags < ApplicationService
    def initialize(entry_id, tag_id = nil)
      @entry_id = entry_id
      @tag_id = tag_id
    end

    def call
      entry = Entry.find(@entry_id)
      content = "#{entry.title} #{entry.description} #{entry.content}"
      tags_found = []

      if @tag_id.nil?
        tags = Tag.all
      else
        tags = Tag.where(id: @tag_id)
      end

      tags.each do |tag|
        tags_found << tag.name if content.match(/\b#{tag.name}\b/)
        if tag.variations
          alts = tag.variations.split(',')
          alts.each { |alt_tag| tags_found << tag.name if content.match(/\b#{alt_tag}\b/) }
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

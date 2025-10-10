# frozen_string_literal: true

module WebExtractorServices
  class ExtractFacebookEntryTags < ApplicationService
    def initialize(facebook_entry_id, tag_id = nil)
      @facebook_entry_id = facebook_entry_id
      @tag_id = tag_id
    end

    def call
      facebook_entry = FacebookEntry.find(@facebook_entry_id)

      content_sources = [
        facebook_entry.message,
        facebook_entry.attachment_title,
        facebook_entry.attachment_description,
        facebook_entry.permalink_url
      ].compact

      content = content_sources.join(' ')
      tags_found = []

      tags_scope =
        if @tag_id.present?
          Tag.where(id: @tag_id)
        else
          Tag.all
        end

      tags_scope.find_each do |tag|
        tags_found << tag.name if tag_match?(content, tag.name)

        next unless tag.variations.present?

        tag.variations.split(',').each do |variation|
          tags_found << tag.name if tag_match?(content, variation)
        end
      end

      if tags_found.empty?
        handle_error('No tags found')
      else
        handle_success(tags_found.uniq)
      end
    rescue StandardError => e
      handle_error(e.message)
    end

    private

    def tag_match?(content, term)
      return false if term.blank?

      content.match?(/\b#{Regexp.escape(term.strip)}\b/i)
    end
  end
end

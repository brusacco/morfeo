# frozen_string_literal: true

module InstagramServices
  class ExtractTags < ApplicationService
    def initialize(instagram_post_id, tag_id = nil)
      @instagram_post_id = instagram_post_id
      @tag_id = tag_id
    end

    def call
      instagram_post = InstagramPost.find(@instagram_post_id)

      # Use only the caption content for tag matching
      content = instagram_post.caption.to_s
      tags_found = []

      tags_scope =
        if @tag_id.present?
          Tag.where(id: @tag_id)
        else
          Tag.all
        end

      tags_scope.find_each do |tag|
        tags_found << tag.name if tag_match?(content, tag.name)

        next if tag.variations.blank?

        tag.variations.split(',').each do |variation|
          tags_found << tag.name if tag_match?(content, variation)
        end
      end

      # If post is linked to an entry, add the entry's tags
      if instagram_post.entry.present?
        entry_tags = instagram_post.entry.tag_list
        tags_found.concat(entry_tags) if entry_tags.any?
      end

      # Remove 'Instagram' tag if present
      tags_found.delete('Instagram')

      if tags_found.empty?
        handle_error('No tags found')
      else
        # Apply the tags to the instagram_post
        instagram_post.tag_list.add(tags_found.uniq)
        instagram_post.save!

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


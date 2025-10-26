# frozen_string_literal: true

module TwitterServices
  class ExtractTags < ApplicationService
    def initialize(twitter_post_id, tag_id = nil)
      @twitter_post_id = twitter_post_id
      @tag_id = tag_id
    end

    def call
      twitter_post = TwitterPost.find(@twitter_post_id)

      # Use only the text content for tag matching
      content = twitter_post.text.to_s
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

      if tags_found.empty?
        handle_error('No tags found')
      else
        # Apply the tags to the twitter_post
        twitter_post.tag_list.add(tags_found.uniq)
        twitter_post.save!

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

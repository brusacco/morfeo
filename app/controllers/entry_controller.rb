# frozen_string_literal: true

class EntryController < ApplicationController
  def show; end

  def popular
    @entries = Entry.joins(:site).has_interactions.a_day_ago.where.not(image_url: nil).order(total_count: :desc)
    @tags = @entries.tag_counts_on(:tags).order('count desc')

    @tags.each do |tag|
      @entries.each do |entry|
        tag.interactions ||= 0
        tag.interactions += entry.total_count
      end
    end

    @tags_count = {}
    @tags.each { |n| @tags_count[n.name] = n.count }

    @tags_interactions = {}
    @entries.each do |entry|
      entry.tags.each do |tag|
        @tags_interactions[tag.name] ||= 0
        @tags_interactions[tag.name] += entry.total_count
      end
    end

    @tags_interactions = @tags_interactions.sort_by { |_k, v| v }
    @tags_interactions.reverse
  end
end

# frozen_string_literal: true

class TagController < ApplicationController
  def show
    @tag = Tag.find(params[:id])
    @entries = Entry.a_month_ago.joins(:site).tagged_with(@tag.name).has_image.order(published_at: :desc)
    @tags = @entries.tag_counts_on(:tags).order('count desc').limit(20)

    # Sets counters and values
    @tags_interactions = Rails.cache.read("tags_interactions_tags_#{@tag.id}")

    # Cache tags interactions
    if @tags_interactions.nil?
      @tags_interactions = {}
      @tags.each do |tag|
        @entries.each do |entry|
          tag.interactions ||= 0
          tag.interactions += entry.total_count if entry.tag_list.include?(tag.name)

          @tags_interactions[tag.name] ||= 0
          @tags_interactions[tag.name] += entry.total_count if entry.tag_list.include?(tag.name)
        end
      end
      Rails.cache.write("tags_interactions_tags_#{@tag.id}", @tags_interactions, expires_in: 1.hour)
    end

    @tags_interactions = @tags_interactions.sort_by { |_k, v| v }
    @tags_interactions.reverse

    @tags_count = {}
    @tags.each { |n| @tags_count[n.name] = n.count }
  end
end

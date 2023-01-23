# frozen_string_literal: true

class TagController < ApplicationController
  def show
    @tag = Tag.find(params[:id])
    @entries = Entry.joins(:site).tagged_with(@tag.name).has_image.order(published_at: :desc).limit(250)
    @tags = @entries.tag_counts_on(:tags).where.not(id: @tag.id).order('count desc').limit(20)

    @tags_count = {}
    @tags.each { |n| @tags_count[n.name] = n.count if n.name != @tag.name } 

    @tags_interactions = {}
    @entries.each do |entry|
      entry.tags.each do |tag|
        @tags_interactions[tag.name] ||= 0
        @tags_interactions[tag.name] += entry.total_count if tag.name != @tag.name
      end
    end

    @tags_interactions = @tags_interactions.sort_by{|k,v| v}.reverse

  end
end

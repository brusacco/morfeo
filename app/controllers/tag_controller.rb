# frozen_string_literal: true

class TagController < ApplicationController
  def show
    @tag = Tag.find(params[:id])
    @entries = Entry.joins(:site).tagged_with(@tag.name).where.not(image_url: nil).order(published_at: :desc).limit(250)
    @tags = @entries.tag_counts_on(:tags).where.not(id: @tag.id).order('count desc').limit(20)

    @entries.each do |entry|
      entry.tags.each do |tag|
        @tags.each do |t|
          t.interactions = 0 if t.interactions.nil?
          t.interactions += entry.total_count if tag.id == t.id
        end
      end
    end
  end
end

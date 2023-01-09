# frozen_string_literal: true

class TagController < ApplicationController
  def show
    @tag = Tag.find(params[:id])
    @entries = Entry.joins(:site).tagged_with(@tag.name).has_image.order(published_at: :desc).limit(250)
    @tags = @entries.tag_counts_on(:tags).where.not(id: @tag.id).order('count desc').limit(20)
  end
end

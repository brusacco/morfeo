# frozen_string_literal: true

class SiteController < ApplicationController
  def show
    @site = Site.find(params[:id])
    @entries_stats = @site.entries.a_month_ago.group_by_day(:published_at)
    @entries = @site.entries.has_interactions.has_image.order(published_at: :desc).limit(250)
    @tags = @entries.tag_counts_on(:tags).order('count desc').limit(20)
  end
end

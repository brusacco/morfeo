# frozen_string_literal: true

class SiteController < ApplicationController
  before_action :authenticate_user!

  def show
    @site = Site.find(params[:id])
    @entries_stats = @site.entries.enabled.normal_range.group_by_day(:published_at)
    @entries = @site.entries.enabled.normal_range.order(published_at: :desc)
    @tags = @entries.tag_counts_on(:tags).order('count desc')

    # Cosas nuevas
    @word_occurrences = word_occurrences(@entries)
    @bigram_occurrences = bigram_occurrences(@entries)

    @tags_interactions = Entry.joins(:tags)
                              .where(id: @entries.select(:id), tags: { id: @tags.map(&:id) })
                              .group('tags.name')
                              .sum(:total_count)
                              .sort_by { |_k, v| -v }

    @tags_count = {}
    @tags.each { |n| @tags_count[n.name] = n.count }
  end
end

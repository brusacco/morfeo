# frozen_string_literal: true

class SiteController < ApplicationController
  before_action :authenticate_user!
  
  def show
    @site = Site.find(params[:id])
    @entries_stats = @site.entries.normal_range.group_by_day(:published_at)
    @entries = @site.entries.normal_range.order(published_at: :desc)
    @tags = @entries.tag_counts_on(:tags).order('count desc')

    # Cosas nuevas
    @word_occurrences = word_occurrences(@entries)
    @bigram_occurrences = bigram_occurrences(@entries)

    @tags_interactions = {}
    @tags.each do |tag|
      @entries.each do |entry|
        tag.interactions ||= 0
        tag.interactions += entry.total_count if entry.tag_list.include?(tag.name)

        @tags_interactions[tag.name] ||= 0
        @tags_interactions[tag.name] += entry.total_count if entry.tag_list.include?(tag.name)
      end
    end

    @tags_interactions = @tags_interactions.sort_by { |_k, v| v }
    @tags_interactions.reverse

    @tags_count = {}
    @tags.each { |n| @tags_count[n.name] = n.count }
  end
end

# frozen_string_literal: true

class SiteController < ApplicationController
  def show
    @site = Site.find(params[:id])
    @entries_stats = @site.entries.a_week_ago.group_by_day(:published_at)
    @entries = @site.entries.has_image.order(published_at: :desc).limit(250)
    @tags = @entries.tag_counts_on(:tags).order('count desc')

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

    @bigrams = {}
    @entries.each do |entry|
      entry.ngrams.each do |bigram|
        @bigrams[bigram] ||= 0
        @bigrams[bigram] += 1
      end
    end

    @bigrams.delete_if { |_k, v| v < 2 }
    @bigrams = @bigrams.sort_by { |_k, v| v }.reverse.take(50)
  end
end

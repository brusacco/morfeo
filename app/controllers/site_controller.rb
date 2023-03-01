# frozen_string_literal: true

class SiteController < ApplicationController
  def show
    @site = Site.find(params[:id])
    @entries_stats = @site.entries.a_month_ago.group_by_day(:published_at)
    @entries = @site.entries.has_interactions.has_image.order(published_at: :desc).limit(250)
    @tags = @entries.tag_counts_on(:tags).order('count desc').limit(20)

    @bigrams = Rails.cache.read("bigrams_interactions_sites_#{@site.id}")
    if @bigrams.nil?
      @bigrams = {}
      @site.entries.a_month_ago.each do |entry|
        entry.generate_bigrams.each do |bigram|
          @bigrams[bigram] ||= 0
          @bigrams[bigram] += entry.total_count
        end
      end
      @bigrams = @bigrams.sort_by { |_k, v| v }.reverse
      @bigrams = @bigrams.select { |_k, v| v > 0 }
      @bigrams = @bigrams.take(50)
    end

     # Sets counters and values
     @tags_interactions = Rails.cache.read("tags_interactions_sites_#{@site.id}")

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
       Rails.cache.write("tags_interactions_sites_#{@site.id}", @tags_interactions, expires_in: 1.hour)
     end
 

    @tags_interactions = @tags_interactions.sort_by { |_k, v| v }
    @tags_interactions.reverse

    @tags_count = {}
    @tags.each { |n| @tags_count[n.name] = n.count }
  end
end

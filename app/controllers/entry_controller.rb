# frozen_string_literal: true

class EntryController < ApplicationController
  def show; end

  def popular
    @entries = Entry.joins(:site).a_day_ago.where.not(image_url: nil).order(total_count: :desc)
    @tags = @entries.tag_counts_on(:tags).order('count desc')

    # Sets counters and values
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

  def twitter
    @entries = Entry.joins(:site).a_day_ago.where.not(image_url: nil).order(tw_total: :desc)
    @tags = @entries.tag_counts_on(:tags).order('count desc')

    # Sets counters and values
    @tags_interactions = {}
    @tags.each do |tag|
      @entries.each do |entry|
        tag.interactions ||= 0
        tag.interactions += entry.tw_total if entry.tag_list.include?(tag.name)

        @tags_interactions[tag.name] ||= 0
        @tags_interactions[tag.name] += entry.tw_total if entry.tag_list.include?(tag.name)
      end
    end

    @tags_interactions = @tags_interactions.sort_by { |_k, v| v }
    @tags_interactions.reverse

    @tags_count = {}
    @tags.each { |n| @tags_count[n.name] = n.count }
  end

  def commented
    @entries = Entry.joins(:site).a_day_ago.where.not(image_url: nil).order(comment_count: :desc)
    @tags = @entries.tag_counts_on(:tags).order('count desc')

     # Sets counters and values
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

# frozen_string_literal: true

class TagController < ApplicationController
  def show
    @tag = Tag.find(params[:id])
    @entries = Entry.normal_range.joins(:site).tagged_with(@tag.name).has_image.order(published_at: :desc)
    @tags = @entries.tag_counts_on(:tags).order('count desc').limit(20)

    @tags_interactions = {}
    @tags.each do |tag|
      @entries.each do |entry|
        if entry.tag_list.include?(tag.name)
          tag.interactions ||= 0
          tag.interactions += entry.total_count

          @tags_interactions[tag.name] ||= 0
          @tags_interactions[tag.name] += entry.total_count
        end
      end
    end
    
    @tags_interactions = @tags_interactions.sort_by { |_k, v| v }.reverse

    @tags_count = {}
    @tags.each { |n| @tags_count[n.name] = n.count }

    @bigrams = {}
    @trigrams = {}

    @entries.each do |entry|
      entry.bigrams.each do |bigram|
        @bigrams[bigram] ||= 0
        @bigrams[bigram] += 1
      end
      entry.trigrams.each do |bigram|
        @trigrams[bigram] ||= 0
        @trigrams[bigram] += 1
      end
    end

    @bigrams.delete_if { |_k, v| v < 2 }
    @bigrams = @bigrams.sort_by { |_k, v| v }.reverse.take(50)

    @trigrams.delete_if { |_k, v| v < 2 }
    @trigrams = @trigrams.sort_by { |_k, v| v }.reverse.take(50)

  end
end

# frozen_string_literal: true

class TagController < ApplicationController
  def show
    @tag = Tag.find(params[:id])
    @entries = Entry.a_month_ago.joins(:site).tagged_with(@tag.name).has_image.order(published_at: :desc)
    @tags = @entries.tag_counts_on(:tags).order('count desc').limit(20)

    # @bigrams = {}
    # @entries.each do |entry|
    #   entry.generate_bigrams.each do |bigram|
    #     @bigrams[bigram] ||= 0
    #     @bigrams[bigram] += entry.total_count
    #   end
    # end
    # @bigrams = @bigrams.sort_by { |_k, v| v }.reverse
    # @bigrams = @bigrams.select { |_k, v| v > 0 }
    # @bigrams = @bigrams.take(50)

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
    @entries.each do |entry|
      entry.bigrams.each do |bigram|
        @bigrams[bigram] ||= 0
        @bigrams[bigram] += 1
      end
    end
    
    @bigrams.delete_if { |_k, v| v < 2 }
    @bigrams = @bigrams.sort_by { |_k, v| v }.reverse

  end
end

# frozen_string_literal: true

class TopicController < ApplicationController
  def show
    @topic = Topic.find(params[:id])
    @tag_list = @topic.tags.map(&:name)
    @entries = Entry.normal_range.joins(:site).tagged_with(@tag_list, any: true).has_image.order(published_at: :desc)

    @top_entries = Entry.normal_range.joins(:site).order(total_count: :desc).limit(5)
    @total_entries = @entries.size
    @total_interactions = @entries.sum(&:total_count)

    # Cosas nuevas
    @word_occurrences = word_occurrences(@entries)
    @bigram_occurrences = bigram_occurrences(@entries)

    @most_interactions = @entries.sort_by(&:total_count).reverse.take(8)

    if @total_entries.zero?
      @promedio = 0
    else
      @promedio = @total_interactions / @total_entries
    end

    @tags = @entries.tag_counts_on(:tags).order('count desc').limit(20)

    @tags_interactions = {}
    @tags.each do |tag|
      @entries.each do |entry|
        next unless entry.tag_list.include?(tag.name)

        tag.interactions ||= 0
        tag.interactions += entry.total_count

        @tags_interactions[tag.name] ||= 0
        @tags_interactions[tag.name] += entry.total_count
      end
    end

    @tags_interactions = @tags_interactions.sort_by { |_k, v| v }
                                           .reverse

    @tags_count = {}
    @tags.each { |n| @tags_count[n.name] = n.count }
  end
end

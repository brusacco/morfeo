# frozen_string_literal: true

class TagController < ApplicationController
  def show
    @tag = Tag.find(params[:id])
    @entries = Entry.normal_range.joins(:site).tagged_with(@tag.name).has_image.order(published_at: :desc)
    @total_entries = @entries.size
    @total_interactions = @entries.sum(:total_count)

    @top_entries = Entry.normal_range.joins(:site).order(total_count: :desc).limit(5)

    @most_interactions = @entries.sort_by(&:total_count).reverse.take(10)

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

  def report
    @tag = Tag.find(params[:id])
    @entries = Entry.normal_range.joins(:site).tagged_with(@tag.name).has_image.order(published_at: :desc)
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

    render layout: false
  end

  def search
    query = params[:query].strip
    @tags = Tag.where('name LIKE?', "%#{query}%")
  end
end

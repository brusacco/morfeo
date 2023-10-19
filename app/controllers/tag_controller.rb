# frozen_string_literal: true

class TagController < ApplicationController
  before_action :authenticate_user!
  
  def show
    @tag = Tag.find(params[:id])

    @entries = Entry.normal_range.joins(:site).tagged_with(@tag.name).order(published_at: :desc)
    @analytics = Entry.normal_range.joins(:site).tagged_with(@tag.name).order(total_count: :desc).limit(20)

    @total_entries = @entries.size
    @total_interactions = @entries.sum(:total_count)

    @comments = Comment.where(entry_id: @entries.pluck(:id))
    @comments_word_occurrences = @comments.word_occurrences
    @comments_bigram_occurrences = @comments.bigram_occurrences

    # Cosas nuevas
    @word_occurrences = @entries.word_occurrences
    @bigram_occurrences = @entries.bigram_occurrences

    @positives = @entries.where(polarity: 1).count('*')
    @negatives = @entries.where(polarity: 2).count('*')
    @neutrals = @entries.where(polarity: 0).count('*')
    
    @percentage_positives = (@positives.to_f / @entries.size * 100).round(0) if @positives > 0
    @percentage_negatives = (@negatives.to_f / @entries.size * 100).round(0) if @negatives > 0
    @percentage_neutrals = (@neutrals.to_f / @entries.size * 100).round(0) if @neutrals > 0

    @top_entries = Entry.normal_range.joins(:site).order(total_count: :desc).limit(5)
    @most_interactions = @entries.sort_by(&:total_count).reverse.take(8)

    if @total_entries.zero?
      @promedio = 0
    else
      @promedio = @total_interactions / @total_entries
    end

    @tags = @entries.tag_counts_on(:tags).order('count desc').limit(50)

    @comments = Comment.where(entry_id: @entries.pluck(:id))
    @comments_word_occurrences = @comments.word_occurrences
    @comments_bigram_occurrences = @comments.bigram_occurrences

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

  def comments
    @tag = Tag.find(params[:id])
    @entries = Entry.normal_range.joins(:site).tagged_with(@tag.name).has_image.order(published_at: :desc)

    @comments = Comment.where(entry_id: @entries.pluck(:id)).order(created_time: :desc)
    @comments_word_occurrences = @comments.word_occurrences
    @comments_bigram_occurrences = @comments.bigram_occurrences

    @tm = TextMood.new(language: 'es', normalize_score: true)
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

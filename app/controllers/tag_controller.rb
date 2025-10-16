# frozen_string_literal: true

class TagController < ApplicationController
  before_action :authenticate_user!

  def show
    @tag = Tag.find(params[:id])
    @entries = @tag.list_entries

    @total_entries = @entries.size
    @total_interactions = @entries.sum(:total_count)

    @comments = Comment.where(entry_id: @entries.select(:id))
    @comments_word_occurrences = @comments.word_occurrences
    # @comments_bigram_occurrences = @comments.bigram_occurrences

    # Cosas nuevas
    @word_occurrences = @entries.word_occurrences
    @bigram_occurrences = @entries.bigram_occurrences

    polarity_counts = @entries.group(:polarity).count
    @neutrals = polarity_counts['neutral'] || 0
    @positives = polarity_counts['positive'] || 0
    @negatives = polarity_counts['negative'] || 0

    @percentage_positives = safe_percentage(@positives, @entries.size)
    @percentage_negatives = safe_percentage(@negatives, @entries.size)
    @percentage_neutrals = safe_percentage(@neutrals, @entries.size)

    @top_entries = Entry.enabled.normal_range.joins(:site).order(total_count: :desc).limit(5)
    @most_interactions = @entries.order(total_count: :desc).limit(12)

    # Precompute pluck values to avoid SQL queries in views
    @top_entries_counts = @top_entries.pluck(:total_count)
    @most_interactions_counts = @most_interactions.limit(5).pluck(:total_count)

    if @total_entries.zero?
      @promedio = 0
    else
      @promedio = @total_interactions / @total_entries
    end

    @tags = @entries.tag_counts_on(:tags).order('count desc').limit(50)

    @tags_interactions = Entry.joins(:tags)
                              .where(id: @entries.select(:id), tags: { id: @tags.map(&:id) })
                              .group('tags.name')
                              .order(Arel.sql('SUM(total_count) DESC'))
                              .sum(:total_count)
    @tags_count = {}
    @tags.each { |n| @tags_count[n.name] = n.count }
  end

  def comments
    @tag = Tag.find(params[:id])
    @entries = Entry.enabled.normal_range.joins(:site).tagged_with(@tag.name).has_image.order(published_at: :desc)

    @comments = Comment.where(entry_id: @entries.select(:id)).order(created_time: :desc)
    @comments_word_occurrences = @comments.word_occurrences
    # @comments_bigram_occurrences = @comments.bigram_occurrences

    @tm = TextMood.new(language: 'es', normalize_score: true)
  end

  def report
    @tag = Tag.find(params[:id])
    @entries = Entry.enabled.normal_range.joins(:site).tagged_with(@tag.name).has_image.order(published_at: :desc)
    @tags = @entries.tag_counts_on(:tags).order('count desc').limit(20)

    @tags_interactions = Entry.joins(:tags)
                              .where(id: @entries.select(:id), tags: { id: @tags.map(&:id) })
                              .group('tags.name')
                              .order(Arel.sql('SUM(total_count) DESC'))
                              .sum(:total_count)

    @tags_count = {}
    @tags.each { |n| @tags_count[n.name] = n.count }

    render layout: false
  end

  def search
    query = params[:query].strip
    @tags = Tag.where('name LIKE?', "%#{query}%")
  end

  private

  def safe_percentage(numerator, denominator)
    denominator.positive? ? (Float(numerator) / denominator * 100).round(0) : 0
  end
end

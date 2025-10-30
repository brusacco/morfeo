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

    @word_occurrences = @entries.word_occurrences
    @bigram_occurrences = @entries.bigram_occurrences

    polarity_counts = @entries.group(:polarity).count
    @neutrals = polarity_counts['neutral'] || 0
    @positives = polarity_counts['positive'] || 0
    @negatives = polarity_counts['negative'] || 0

    @percentage_positives = safe_percentage(@positives, @entries.size)
    @percentage_negatives = safe_percentage(@negatives, @entries.size)
    @percentage_neutrals = safe_percentage(@neutrals, @entries.size)

    @promedio = @total_entries.zero? ? 0 : @total_interactions / @total_entries

    @most_interactions = @entries.order(total_count: :desc).limit(20)

    @title_entries = @tag.title_list_entries
    @title_chart_entries = @title_entries.group_by_day(:published_at)
    @title_chart_entries_counts = @title_chart_entries.count
    @title_chart_entries_sums = @title_chart_entries.sum(:total_count)

    @site_top_counts = @entries.group('site_id').order(Arel.sql('COUNT(*) DESC')).limit(12).count
    @site_counts = @entries.group('sites.name').count('*')
    @site_sums = @entries.group('sites.name').sum(:total_count)

    @tags = @entries.tag_counts_on(:tags).where.not(id: @tag.id).order('count desc').limit(50)

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

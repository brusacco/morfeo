# frozen_string_literal: true

class TopicController < ApplicationController
  before_action :authenticate_user!

  def show
    @topic = Topic.find(params[:id])

    return redirect_to root_path, alert: 'El Tópico al que intentaste acceder no está asignado a tu usuario' unless @topic.users.exists?(current_user.id)

    @tag_list = @topic.tags.map(&:name)
    @entries = @topic.topic_entries
    @analytics = @topic.analytics_topic_entries

    @top_entries = Entry.normal_range.joins(:site).order(total_count: :desc).limit(5)
    @total_entries = @entries.size
    @total_interactions = @entries.sum(&:total_count)

    # Calcular numeros de totales de la semana
    @all_entries = Entry.normal_range.joins(:site).order(published_at: :desc).where.not(id: @entries.ids)

    # Cosas nuevas
    @word_occurrences = @entries.word_occurrences
    @bigram_occurrences = @entries.bigram_occurrences
    @report = @topic.reports.last

    @comments = Comment.where(entry_id: @entries.pluck(:id))
    @comments_word_occurrences = @comments.word_occurrences
    @comments_bigram_occurrences = @comments.bigram_occurrences

    @positive_words = @topic.positive_words.split(',') if @topic.positive_words.present?
    @negative_words = @topic.negative_words.split(',') if @topic.negative_words.present?

    @positives = @entries.where(polarity: 1).count('*')
    @negatives = @entries.where(polarity: 2).count('*')
    @neutrals = @entries.where(polarity: 0).count('*')

    if @entries.any?
      @percentage_positives = (Float(@positives) / @entries.size * 100).round(0)
      @percentage_negatives = (Float(@negatives) / @entries.size * 100).round(0)
      @percentage_neutrals = (Float(@neutrals) / @entries.size * 100).round(0)

      total_count = @entries.size + @all_entries.size
      @topic_percentage = (Float(@entries.size) / total_count * 100).round(0)
      @all_percentage = (Float(@all_entries.size) / total_count * 100).round(0)

      total_count = @entries.sum(:total_count) + @all_entries.sum(:total_count)
      @topic_interactions_percentage = (Float(@entries.sum(&:total_count)) / total_count * 100).round(1)
      @all_intereactions_percentage = (Float(@all_entries.sum(&:total_count)) / total_count * 100).round(1)
    end

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

  def comments
    @topic = Topic.find(params[:id])

    return redirect_to root_path, alert: 'El Tópico al que intentaste acceder no está asignado a tu usuario' unless @topic.users.exists?(current_user.id)

    @tag_list = @topic.tags.map(&:name)
    @entries = @topic.topic_entries

    @positive_words = @topic.positive_words.split(',') if @topic.positive_words.present?
    @negative_words = @topic.negative_words.split(',') if @topic.negative_words.present?

    @comments = Comment.where(entry_id: @entries.pluck(:id)).order(created_time: :desc)
    @comments_word_occurrences = @comments.word_occurrences
    @comments_bigram_occurrences = @comments.bigram_occurrences

    @tm = TextMood.new(language: 'es', normalize_score: true)
  end

  def history
    @topic = Topic.find(params[:id])
    @reports = @topic.reports.order(created_at: :desc).limit(20)
  end
end

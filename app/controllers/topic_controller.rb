# frozen_string_literal: true

class TopicController < ApplicationController
  before_action :authenticate_user!

  # caches_action :show, expires_in: 1.hour

  def entries_data
    topic_id = params[:topic_id]
    date_filter = params[:date]
    polarity = params[:polarity]

    if date_filter.present?
      date = Date.parse(date_filter)
    end

    topic = Topic.find_by(id: topic_id)

    if topic
      entries = topic.chart_entries(date)
      entries = entries.where(published_at: date.all_day) if date_filter.present?
      entries = entries.where(polarity: polarity) if polarity.present?
    end

    render partial: 'home/chart_entries', locals: { topic_entries: entries, entries_date: date, topic: topic.name }, layout: false
  end

  def show
    @topic = Topic.find(params[:id])

    return redirect_to root_path, alert: 'El Tópico al que intentaste acceder no está asignado a tu usuario o se encuentra deshabilitado' unless @topic.users.exists?(current_user.id) && @topic.status == true

    @tag_list = @topic.tags.map(&:name)
    @entries = @topic.list_entries
    @chart_entries = @entries.group_by_day(:published_at)
    @chart_entries_sentiments = @entries.where.not(polarity: nil).group(:polarity).group_by_day(:published_at)

    # @analytics = @topic.analytics_topic_entries

    @top_entries = Entry.enabled.normal_range.joins(:site).order(total_count: :desc).limit(5)
    @total_entries = @entries.size
    @total_interactions = @entries.sum(&:total_count)

    # Calcular numeros de totales de la semana
    # @all_entries = @topic.analytics_entries(@entries.ids)
    @all_entries_size = Entry.enabled.normal_range.where.not(id: @entries.ids).count
    @all_entries_interactions = Entry.enabled.normal_range.where.not(id: @entries.ids).sum(:total_count)

    # Cosas nuevas
    @word_occurrences = @entries.word_occurrences
    @bigram_occurrences = @entries.bigram_occurrences
    @report = @topic.reports.last

    @comments = Comment.where(entry_id: @entries.pluck(:id))
    @comments_word_occurrences = @comments.word_occurrences
    @comments_bigram_occurrences = @comments.bigram_occurrences

    @positive_words = @topic.positive_words.split(',') if @topic.positive_words.present?
    @negative_words = @topic.negative_words.split(',') if @topic.negative_words.present?

    polarity_counts = @entries.group(:polarity).count
    @neutrals = polarity_counts['neutral'] || 0
    @positives = polarity_counts['positive'] || 0
    @negatives = polarity_counts['negative'] || 0

    if @entries.any?
      @percentage_positives = (Float(@positives) / @entries.size * 100).round(0)
      @percentage_negatives = (Float(@negatives) / @entries.size * 100).round(0)
      @percentage_neutrals = (Float(@neutrals) / @entries.size * 100).round(0)

      total_count = @entries.size + @all_entries_size
      @topic_percentage = (Float(@entries.size) / total_count * 100).round(0)
      @all_percentage = (Float(@all_entries_size) / total_count * 100).round(0)

      total_count = @entries.sum(:total_count) + @all_entries_interactions
      @topic_interactions_percentage = (Float(@entries.sum(&:total_count)) / total_count * 100).round(1)
      @all_intereactions_percentage = (Float(@all_entries_interactions) / total_count * 100).round(1)
    end

    @most_interactions = @entries.sort_by(&:total_count).reverse.take(12)

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
    @entries = @topic.list_entries

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

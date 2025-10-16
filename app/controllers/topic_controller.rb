# frozen_string_literal: true

class TopicController < ApplicationController
  before_action :authenticate_user!

  # caches_action :show, expires_in: 1.hour

  def entries_data
    topic_id = params[:topic_id]
    date_filter = params[:date]
    polarity = params[:polarity]
    title = params[:title]

    date = Date.parse(date_filter) if date_filter.present?

    topic = Topic.find_by(id: topic_id)
    polarity = validate_polarity(polarity)

    if topic
      if title == 'true'
        entries = topic.title_chart_entries(date)
      else
        entries = topic.chart_entries(date)
      end

      entries = entries.where(published_at: date.all_day)

      entries = entries.where(polarity:) if polarity
    end

    case polarity
    when 'neutral', '0'
      polarityName = 'Neutral'
    when 'positive', '1'
      polarityName = 'Positiva'
    when 'negative', '2'
      polarityName = 'Negativa'
    else
      polarityName = 'Todas'
    end

    render partial: 'home/chart_entries',
           locals: {
             topic_entries: entries,
             entries_date: date,
             topic: topic.name,
             polarity: polarityName
           },
           layout: false
  end

  def validate_polarity(polarity)
    valid_polarities = %w[neutral positive negative 0 1 2]
    valid_polarities.include?(polarity) ? polarity : nil
  end

  def show
    @topic = Topic.find(params[:id])

    unless @topic.users.exists?(current_user.id) && @topic.status == true
      return redirect_to root_path,
                         alert: 'El Tópico al que intentaste acceder no está asignado a tu usuario o se encuentra deshabilitado'
    end

    @tag_list = @topic.tags.map(&:name)
    @entries = @topic.list_entries

    # Precompute aggregates to avoid multiple SQL queries
    @entries_count = @entries.size
    @entries_total_sum = @entries.sum(:total_count)
    @entries_polarity_counts = @entries.where.not(polarity: nil).group(:polarity).count
    @entries_polarity_sums = @entries.where.not(polarity: nil).group(:polarity).sum(:total_count)

    # Precompute site group queries to avoid duplicate group-by operations
    @site_counts = @entries.group('sites.name').count('*')
    @site_sums = @entries.group('sites.name').sum(:total_count)

    @chart_entries = @entries.group_by_day(:published_at)
    @chart_entries_sentiments = @entries.where.not(polarity: nil).group(:polarity).group_by_day(:published_at)

    @title_entries = @topic.title_list_entries
    @title_chart_entries = @title_entries.reorder(nil).group_by_day(:published_at)

    # Precompute chart data to avoid multiple SQL queries per chart
    @chart_entries_counts = @chart_entries.count
    @chart_entries_sums = @chart_entries.sum(:total_count)
    @title_chart_entries_counts = @title_chart_entries.count
    @title_chart_entries_sums = @title_chart_entries.sum(:total_count)

    # Precompute sentiment chart data
    @chart_entries_sentiments_counts = @chart_entries_sentiments.count('*')
    @chart_entries_sentiments_sums = @chart_entries_sentiments.sum('total_count')

    # @analytics = @topic.analytics_topic_entries

    @top_entries = Entry.enabled.normal_range.joins(:site).order(total_count: :desc).limit(5)
    @total_entries = @entries_count
    @total_interactions = @entries_total_sum

    # Calcular numeros de totales de la semana
    # @all_entries = @topic.analytics_entries(@entries.ids)
    @all_entries_size = @topic.all_list_entries.count
    @all_entries_interactions = @topic.all_list_entries.sum(:total_count)

    # Cosas nuevas
    @word_occurrences =
      Rails.cache.fetch("topic_#{@topic.id}_word_occurrences", expires_in: 1.hour) do
        @entries.word_occurrences
      end
    @bigram_occurrences =
      Rails.cache.fetch("topic_#{@topic.id}_bigram_occurrences", expires_in: 1.hour) do
        @entries.bigram_occurrences
      end
    @report = @topic.reports.last

    # @comments = Comment.where(entry_id: @entries.select(:id))
    # @comments_word_occurrences = @comments.word_occurrences
    # @comments_bigram_occurrences = @comments.bigram_occurrences
    @comments = []
    @comments_word_occurrences = []

    @positive_words = @topic.positive_words.split(',') if @topic.positive_words.present?
    @negative_words = @topic.negative_words.split(',') if @topic.negative_words.present?

    polarity_counts = @entries.group(:polarity).count
    @neutrals = polarity_counts['neutral'] || 0
    @positives = polarity_counts['positive'] || 0
    @negatives = polarity_counts['negative'] || 0

    if @entries.any?
      @percentage_positives = (Float(@positives) / @entries_count * 100).round(0)
      @percentage_negatives = (Float(@negatives) / @entries_count * 100).round(0)
      @percentage_neutrals = (Float(@neutrals) / @entries_count * 100).round(0)

      total_count = @entries_count + @all_entries_size
      @topic_percentage = (Float(@entries_count) / total_count * 100).round(0)
      @all_percentage = (Float(@all_entries_size) / total_count * 100).round(0)

      total_count = @entries_total_sum + @all_entries_interactions
      @topic_interactions_percentage = (Float(@entries_total_sum) / total_count * 100).round(1)
      @all_intereactions_percentage = (Float(@all_entries_interactions) / total_count * 100).round(1)
    end

    @most_interactions = @entries.order(total_count: :desc).limit(12)

    # Precompute pluck values to avoid SQL queries in views
    @top_entries_counts = @top_entries.pluck(:total_count)
    @most_interactions_counts = @most_interactions.limit(5).pluck(:total_count)

    if @total_entries.zero?
      @promedio = 0
    else
      @promedio = @total_interactions / @total_entries
    end

    @tags = Tag.joins(:taggings)
               .where(taggings: {
                        taggable_type: Entry.base_class.name,
                        context: 'tags',
                        taggable_id: @entries.select(:id)
                      })
               .group('tags.id', 'tags.name')
               .order(Arel.sql('COUNT(DISTINCT taggings.taggable_id) DESC'))
               .limit(20)
               .select('tags.id, tags.name, COUNT(DISTINCT taggings.taggable_id) AS count')

    @tags_interactions = Entry.joins(:tags)
                              .where(id: @entries.select(:id), tags: { id: @tags.map(&:id) })
                              .group('tags.name')
                              .sum(:total_count)

    @tags_count = {}
    @tags.each { |n| @tags_count[n.name] = n.count }

    # Precompute top sites for partial to avoid query in view
    @site_top_counts = @entries.group('sites.id').count.sort_by { |_, count| -count }
                               .take(12)
  end

  def comments
    @topic = Topic.find(params[:id])

    unless @topic.users.exists?(current_user.id)
      return redirect_to root_path, alert: 'El Tópico al que intentaste acceder no está asignado a tu usuario'
    end

    @tag_list = @topic.tags.map(&:name)
    @entries = @topic.list_entries

    @positive_words = @topic.positive_words.split(',') if @topic.positive_words.present?
    @negative_words = @topic.negative_words.split(',') if @topic.negative_words.present?

    @comments = Comment.where(entry_id: @entries.select(:id)).order(created_time: :desc)
    @comments_word_occurrences = @comments.word_occurrences
    # @comments_bigram_occurrences = @comments.bigram_occurrences

    @tm = TextMood.new(language: 'es', normalize_score: true)
  end

  def pdf
    @topic = Topic.includes(:tags, :users).find(params[:id])

    unless @topic.users.exists?(current_user.id) && @topic.status == true
      return redirect_to root_path,
                         alert: 'El Tópico al que intentaste acceder no está asignado a tu usuario o se encuentra deshabilitado'
    end

    # Reuse the same data preparation logic as show action
    @tag_list = @topic.tags.map(&:name)
    @entries = @topic.list_entries

    # Precompute aggregates to avoid multiple SQL queries
    @entries_count = @entries.size
    @entries_total_sum = @entries.sum(:total_count)
    @entries_polarity_counts = @entries.where.not(polarity: nil).group(:polarity).count
    @entries_polarity_sums = @entries.where.not(polarity: nil).group(:polarity).sum(:total_count)

    # Precompute site group queries to avoid duplicate group-by operations
    @site_counts = @entries.group('sites.name').count('*')
    @site_sums = @entries.group('sites.name').sum(:total_count)

    @chart_entries = @entries.group_by_day(:published_at)
    @chart_entries_sentiments = @entries.where.not(polarity: nil).group(:polarity).group_by_day(:published_at)

    @title_entries = @topic.title_list_entries
    @title_chart_entries = @title_entries.reorder(nil).group_by_day(:published_at)

    # Precompute chart data to avoid multiple SQL queries per chart
    @chart_entries_counts = @chart_entries.count
    @chart_entries_sums = @chart_entries.sum(:total_count)
    @title_chart_entries_counts = @title_chart_entries.count
    @title_chart_entries_sums = @title_chart_entries.sum(:total_count)

    # Precompute sentiment chart data
    @chart_entries_sentiments_counts = @chart_entries_sentiments.count('*')
    @chart_entries_sentiments_sums = @chart_entries_sentiments.sum('total_count')

    @top_entries = Entry.enabled.normal_range.joins(:site).order(total_count: :desc).limit(5)
    @total_entries = @entries_count
    @total_interactions = @entries_total_sum

    @all_entries_size = Entry.enabled.normal_range.where.not(id: @entries.ids).count
    @all_entries_interactions = Entry.enabled.normal_range.where.not(id: @entries.ids).sum(:total_count)

    @word_occurrences =
      Rails.cache.fetch("topic_#{@topic.id}_word_occurrences", expires_in: 1.hour) do
        @entries.word_occurrences
      end
    @bigram_occurrences =
      Rails.cache.fetch("topic_#{@topic.id}_bigram_occurrences", expires_in: 1.hour) do
        @entries.bigram_occurrences
      end
    @report = @topic.reports.last

    # @comments = Comment.where(entry_id: @entries.select(:id))
    # @comments_word_occurrences = @comments.word_occurrences

    @positive_words = @topic.positive_words.split(',') if @topic.positive_words.present?
    @negative_words = @topic.negative_words.split(',') if @topic.negative_words.present?

    polarity_counts = @entries.group(:polarity).count
    @neutrals = polarity_counts['neutral'] || 0
    @positives = polarity_counts['positive'] || 0
    @negatives = polarity_counts['negative'] || 0

    if @entries.any?
      @percentage_positives = (Float(@positives) / @entries_count * 100).round(0)
      @percentage_negatives = (Float(@negatives) / @entries_count * 100).round(0)
      @percentage_neutrals = (Float(@neutrals) / @entries_count * 100).round(0)

      total_count = @entries_count + @all_entries_size
      @topic_percentage = (Float(@entries_count) / total_count * 100).round(0)
      @all_percentage = (Float(@all_entries_size) / total_count * 100).round(0)

      total_count = @entries_total_sum + @all_entries_interactions
      @topic_interactions_percentage = (Float(@entries_total_sum) / total_count * 100).round(1)
      @all_intereactions_percentage = (Float(@all_entries_interactions) / total_count * 100).round(1)
    end

    @most_interactions = @entries.order(total_count: :desc).limit(12)

    # Precompute pluck values to avoid SQL queries in views
    @top_entries_counts = @top_entries.pluck(:total_count)
    @most_interactions_counts = @most_interactions.limit(5).pluck(:total_count)

    if @total_entries.zero?
      @promedio = 0
    else
      @promedio = @total_interactions / @total_entries
    end

    @tags = @entries.tag_counts_on(:tags).order(count: :desc).limit(20)

    @tags_interactions = Entry.joins(:tags)
                              .where(id: @entries.select(:id), tags: { id: @tags.map(&:id) })
                              .group('tags.name')
                              .order('SUM(total_count) DESC')
                              .sum(:total_count)

    @tags_count = {}
    @tags.each { |n| @tags_count[n.name] = n.count }

    # Precompute top sites for partial to avoid query in view
    @site_top_counts = @entries.group('sites.id').count.sort_by { |_, count| -count }
                               .take(12)

    # Render with specific layout for PDF
    render layout: false
  end

  def history
    @topic = Topic.find(params[:id])
    @reports = @topic.reports.where.not(report_text: nil).order(created_at: :desc).limit(20)
  end
end

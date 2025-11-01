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

    # Use service to load all data
    dashboard_data = DigitalDashboardServices::AggregatorService.call(topic: @topic)

    # Assign data to instance variables for the view
    assign_topic_data(dashboard_data[:topic_data])
    assign_chart_data(dashboard_data[:chart_data])
    assign_percentages(dashboard_data[:percentages])
    assign_tags_and_words(dashboard_data[:tags_and_words])
    assign_temporal_intelligence(dashboard_data[:temporal_intelligence])
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

    # Use service to load all data
    dashboard_data = DigitalDashboardServices::AggregatorService.call(topic: @topic)

    # Assign data to instance variables for the view
    assign_topic_data(dashboard_data[:topic_data])
    assign_chart_data(dashboard_data[:chart_data])
    assign_tags_and_words(dashboard_data[:tags_and_words])
    
    # For PDF, calculate percentages differently
    calculate_percentages_for_pdf

    # Render with specific layout for PDF
    render layout: false
  end

  def history
    @topic = Topic.find(params[:id])
    @reports = @topic.reports.where.not(report_text: nil).order(created_at: :desc).limit(20)
  end

  private

  # Assignment methods for service data
  def assign_topic_data(data)
    @tag_list = data[:tag_list]
    @entries = data[:entries]
    @entries_count = data[:entries_count]
    @entries_total_sum = data[:entries_total_sum]
    @entries_polarity_counts = data[:entries_polarity_counts]
    @entries_polarity_sums = data[:entries_polarity_sums]
    @site_counts = data[:site_counts]
    @site_sums = data[:site_sums]
    @total_entries = data[:total_entries]
    @total_interactions = data[:total_interactions]
  end

  def assign_chart_data(data)
    @chart_entries_counts = data[:chart_entries_counts]
    @chart_entries_sums = data[:chart_entries_sums]
    @chart_entries_sentiments_counts = data[:chart_entries_sentiments_counts]
    @chart_entries_sentiments_sums = data[:chart_entries_sentiments_sums]
    @title_chart_entries_counts = data[:title_chart_entries_counts]
    @title_chart_entries_sums = data[:title_chart_entries_sums]
  end

  def assign_percentages(data)
    @percentage_positives = data[:percentage_positives]
    @percentage_negatives = data[:percentage_negatives]
    @percentage_neutrals = data[:percentage_neutrals]
    @topic_percentage = data[:topic_percentage]
    @all_percentage = data[:all_percentage]
    @topic_interactions_percentage = data[:topic_interactions_percentage]
    @all_intereactions_percentage = data[:all_interactions_percentage]
    @promedio = data[:promedio]
    @most_interactions = data[:most_interactions]
    @neutrals = data[:neutrals]
    @positives = data[:positives]
    @negatives = data[:negatives]
    @all_entries_size = data[:all_entries_size]
    @all_entries_interactions = data[:all_entries_interactions]
  end

  def assign_tags_and_words(data)
    @word_occurrences = data[:word_occurrences]
    @bigram_occurrences = data[:bigram_occurrences]
    @report = data[:report]
    @comments = data[:comments]
    @comments_word_occurrences = data[:comments_word_occurrences]
    @positive_words = data[:positive_words]
    @negative_words = data[:negative_words]
    @tags = data[:tags]
    @tags_interactions = data[:tags_interactions]
    @tags_count = data[:tags_count]
    @site_top_counts = data[:site_top_counts]
  end

  def assign_temporal_intelligence(data)
    @temporal_summary = data[:temporal_summary]
    @optimal_time = data[:optimal_time]
    @trend_velocity = data[:trend_velocity]
    @engagement_velocity = data[:engagement_velocity]
    @content_half_life = data[:content_half_life]
    @peak_hours = data[:peak_hours]
    @peak_days = data[:peak_days]
    @heatmap_data = data[:heatmap_data]
  end

  # Special calculation for PDF (exclude current topic entries)
  def calculate_percentages_for_pdf
    # Calculate all entries stats differently for PDF
    @all_entries_size = Entry.enabled.normal_range.where.not(id: @entries.ids).count
    @all_entries_interactions = Entry.enabled.normal_range.where.not(id: @entries.ids).sum(:total_count)

    # Recalculate based on PDF requirements
    if @entries_count > 0
      total_count = @entries_count + @all_entries_size
      if total_count > 0
        @topic_percentage = (Float(@entries_count) / total_count * 100).round(0)
        @all_percentage = (Float(@all_entries_size) / total_count * 100).round(0)
      end

      total_interactions = @entries_total_sum + @all_entries_interactions
      if total_interactions > 0
        @topic_interactions_percentage = (Float(@entries_total_sum) / total_interactions * 100).round(1)
        @all_intereactions_percentage = (Float(@all_entries_interactions) / total_interactions * 100).round(1)
      end
    end
  end
end

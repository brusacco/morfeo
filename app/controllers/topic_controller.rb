# frozen_string_literal: true

class TopicController < ApplicationController
  include TopicAuthorizable
  
  before_action :authenticate_user!
  before_action :set_topic, only: [:show, :pdf, :comments, :history]
  before_action :authorize_topic_access!, only: [:show, :pdf]

  # caches_action :show, expires_in: 1.hour

  def entries_data
    topic_id = params[:topic_id]
    date_filter = params[:date]
    polarity = params[:polarity]
    title = params[:title]

    # Validate topic exists
    topic = Topic.find_by(id: topic_id)
    unless topic
      render partial: 'shared/error_message',
             locals: { message: 'Tópico no encontrado' },
             status: :not_found
      return
    end

    # Parse date with error handling
    date = parse_date_filter(date_filter)
    unless date
      render partial: 'shared/error_message',
             locals: { message: 'Fecha inválida' },
             status: :bad_request
      return
    end

    # Validate polarity
    polarity = validate_polarity(polarity)

    # Load entries based on parameters
    entries = if title == 'true'
                topic.title_chart_entries(date)
              else
                topic.chart_entries(date)
              end

    entries = entries.where(published_at: date.all_day)
    entries = entries.where(polarity: polarity) if polarity

    # Determine polarity name for display
    polarity_name = case polarity
                    when 'neutral', '0' then 'Neutral'
                    when 'positive', '1' then 'Positiva'
                    when 'negative', '2' then 'Negativa'
                    else 'Todas'
                    end

    render partial: 'home/chart_entries',
           locals: {
             topic_entries: entries,
             entries_date: date,
             topic: topic.name,
             polarity: polarity_name
           },
           layout: false
  rescue ActiveRecord::RecordNotFound => e
    Rails.logger.error "Topic not found in entries_data: #{e.message}"
    render partial: 'shared/error_message',
           locals: { message: 'Tópico no encontrado' },
           status: :not_found
  rescue StandardError => e
    Rails.logger.error "Error in entries_data: #{e.class} - #{e.message}"
    Rails.logger.error e.backtrace.first(5).join("\n")
    render partial: 'shared/error_message',
           locals: { message: 'Error cargando datos. Por favor intente nuevamente.' },
           status: :internal_server_error
  end

  def parse_date_filter(date_string)
    return Date.current if date_string.blank?
    
    Date.parse(date_string)
  rescue ArgumentError => e
    Rails.logger.warn "Invalid date parameter: #{date_string} - #{e.message}"
    nil
  end

  def validate_polarity(polarity)
    valid_polarities = %w[neutral positive negative 0 1 2]
    valid_polarities.include?(polarity) ? polarity : nil
  end

  def show
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
    # Use dedicated PDF service
    pdf_data = DigitalDashboardServices::PdfService.call(topic: @topic)

    # Assign data to instance variables for the PDF view
    assign_topic_data(pdf_data[:topic_data])
    assign_chart_data(pdf_data[:chart_data])
    assign_tags_and_words(pdf_data[:tags_and_words])
    assign_percentages(pdf_data[:percentages])

    # Render with specific layout for PDF
    render layout: false
  end

  def history
    @reports = @topic.reports.where.not(report_text: nil).order(created_at: :desc).limit(20)
  end

  private

  def set_topic
    @topic = Topic.includes(:tags, :users).find(params[:id])
  end

  # Helper class for grouped data in PDF
  class GroupProxy
    attr_reader :count_data, :sum_data, :id_data, :column
    
    def initialize(count_data, sum_data, id_data, column)
      @count_data = count_data
      @sum_data = sum_data
      @id_data = id_data
      @column = column
    end
    
    def count(*)
      column == 'sites.id' ? id_data : count_data
    end
    
    def sum(field)
      sum_data
    end
  end

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
    
    # For PDF - wrap @entries to provide pre-calculated grouped data
    if data[:entries_by_site_count] && data[:entries_by_site_sum] && data[:entries_by_site_id]
      entries_original = @entries
      by_site_count = data[:entries_by_site_count]
      by_site_sum = data[:entries_by_site_sum]
      by_site_id = data[:entries_by_site_id]
      total_sum = data[:entries_total_sum]
      
      @entries = Struct.new(:relation, :by_site_count, :by_site_sum, :by_site_id, :total_sum) do
        # Delegate most methods to the original relation
        def method_missing(method, *args, &block)
          relation.send(method, *args, &block)
        end
        
        def respond_to_missing?(method, include_private = false)
          relation.respond_to?(method, include_private) || super
        end
        
        # Override group to return pre-calculated data
        def group(column)
          TopicController::GroupProxy.new(by_site_count, by_site_sum, by_site_id, column)
        end
        
        # Override sum to return pre-calculated total when called directly
        def sum(field = nil)
          if field == :total_count || field == 'total_count'
            total_sum
          else
            relation.sum(field)
          end
        end
      end.new(entries_original, by_site_count, by_site_sum, by_site_id, total_sum)
    end
  end

  def assign_chart_data(data)
    @chart_entries_counts = data[:chart_entries_counts]
    @chart_entries_sums = data[:chart_entries_sums]
    @chart_entries_sentiments_counts = data[:chart_entries_sentiments_counts]
    @chart_entries_sentiments_sums = data[:chart_entries_sentiments_sums]
    @title_chart_entries_counts = data[:title_chart_entries_counts]
    @title_chart_entries_sums = data[:title_chart_entries_sums]
    
    # For PDF - create objects that respond to count and sum methods for chartkick
    if data[:title_chart_entries_count_data] && data[:title_chart_entries_sum_data]
      @title_chart_entries = create_chart_object(
        data[:title_chart_entries_count_data], 
        data[:title_chart_entries_sum_data]
      )
    end
    
    if data[:chart_entries_sentiments_count_data] && data[:chart_entries_sentiments_sum_data]
      @chart_entries_sentiments = create_chart_object(
        data[:chart_entries_sentiments_count_data],
        data[:chart_entries_sentiments_sum_data]
      )
    end
  end
  
  def create_chart_object(count_data, sum_data)
    Struct.new(:count_data, :sum_data) do
      def count(*)
        count_data
      end
      
      def sum(*)
        sum_data
      end
    end.new(count_data, sum_data)
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
end

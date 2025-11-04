# frozen_string_literal: true

class TwitterTopicController < ApplicationController
  include TopicAuthorizable
  
  before_action :authenticate_user!
  before_action :set_topic
  before_action :authorize_topic_access!, only: [:show, :pdf]

  # Constants
  TOP_POSTS_SHOW_LIMIT = 20
  TOP_POSTS_PDF_LIMIT = 10
  TAG_LIMIT = 20
  SITE_LIMIT = 12
  CACHE_DURATION = 30.minutes

  caches_action :show, :pdf, expires_in: CACHE_DURATION,
                cache_path: proc { |c| { topic_id: c.params[:id], user_id: c.current_user.id, days_range: c.params[:days_range] } }

  def show
    # Use service to load all data
    dashboard_data = TwitterDashboardServices::AggregatorService.call(
      topic: @topic,
      top_posts_limit: TOP_POSTS_SHOW_LIMIT,
      days_range: DAYS_RANGE
    )

    # Assign data to instance variables for the view
    assign_twitter_data(dashboard_data[:twitter_data])
    assign_profiles_data(dashboard_data[:profiles_data])
    assign_temporal_intelligence(dashboard_data[:temporal_intelligence])
    @viral_content = dashboard_data[:viral_content]
  end

  def entries_data
    # Validate topic exists (set by set_topic before_action)
    unless @topic
      render partial: 'shared/error_message',
             locals: { message: 'Tópico no encontrado' },
             status: :not_found
      return
    end

    # Parse date with error handling
    date = parse_date_param || Date.current
    
    # Load Twitter posts for the date
    posts = TwitterPost.for_topic(@topic, start_time: date.beginning_of_day, end_time: date.end_of_day)
                       .reorder(Arel.sql('(favorite_count + retweet_count + reply_count + quote_count) DESC'))

    render partial: 'twitter_topic/chart_entries',
           locals: { posts: posts, entries_date: date, topic_name: @topic.name }
  rescue ActiveRecord::RecordNotFound => e
    Rails.logger.error "Error loading Twitter posts: #{e.message}"
    render partial: 'shared/error_message',
           locals: { message: 'Tópico no encontrado' },
           status: :not_found
  rescue StandardError => e
    Rails.logger.error "Error in Twitter entries_data: #{e.class} - #{e.message}"
    Rails.logger.error e.backtrace.first(5).join("\n")
    render partial: 'shared/error_message',
           locals: { message: 'Error cargando publicaciones de Twitter. Por favor intente nuevamente.' },
           status: :internal_server_error
  end

  def pdf
    # Get days_range from params, default to 7 days if not provided or invalid
    @days_range = (params[:days_range].presence&.to_i || DAYS_RANGE || 7)
    
    # Use service to load data for PDF
    dashboard_data = TwitterDashboardServices::AggregatorService.call(
      topic: @topic,
      top_posts_limit: TOP_POSTS_PDF_LIMIT,
      days_range: @days_range
    )

    # Assign data to instance variables for the view
    assign_twitter_data(dashboard_data[:twitter_data])
    assign_profiles_data(dashboard_data[:profiles_data])

    # Render with specific layout for PDF
    render layout: false
  end

  private

  def set_topic
    topic_id = params[:id] || params[:topic_id]
    @topic = Topic.find(topic_id)
  end

  def parse_date_param
    Date.parse(params[:date]) if params[:date].present?
  rescue ArgumentError => e
    Rails.logger.warn "Invalid date parameter: #{params[:date]} - #{e.message}"
    nil
  end

  # Assignment methods for service data
  def assign_twitter_data(data)
    @tag_list = data[:tag_list]
    @posts = data[:posts]
    @chart_posts = data[:chart_posts]
    @chart_interactions = data[:chart_interactions]
    @total_posts = data[:total_posts]
    @total_interactions = data[:total_interactions]
    @total_views = data[:total_views]
    @average_interactions = data[:average_interactions]
    @top_posts = data[:top_posts]
    @word_occurrences = data[:word_occurrences]
    @bigram_occurrences = data[:bigram_occurrences]
    @tag_counts = data[:tag_counts]
    @positive_words = data[:positive_words]
    @negative_words = data[:negative_words]
    @tag_interactions = data[:tag_interactions]
  end

  def assign_profiles_data(data)
    @profiles_count = data[:profiles_count]
    @profiles_interactions = data[:profiles_interactions]
    @site_top_counts = data[:site_top_counts]
    @site_counts = data[:site_counts]
    @site_sums = data[:site_sums]
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

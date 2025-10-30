# frozen_string_literal: true

class TwitterTopicController < ApplicationController
  before_action :authenticate_user!
  before_action :set_topic
  before_action :authorize_topic!

  # Constants
  TOP_POSTS_SHOW_LIMIT = 20
  TOP_POSTS_PDF_LIMIT = 10
  TAG_LIMIT = 20
  SITE_LIMIT = 12
  CACHE_DURATION = 1.hour

  caches_action :show, :pdf, expires_in: CACHE_DURATION,
                cache_path: proc { |c| { topic_id: c.params[:id], user_id: c.current_user.id } }

  def show
    load_twitter_data
    load_profiles_data
    load_twitter_temporal_intelligence
  end

  def entries_data
    date = parse_date_param || Date.current
    posts = TwitterPost.for_topic(@topic, start_time: date.beginning_of_day, end_time: date.end_of_day)
                       .reorder(Arel.sql('(favorite_count + retweet_count + reply_count + quote_count) DESC'))

    render partial: 'twitter_topic/chart_entries', locals: { posts:, entries_date: date, topic_name: @topic.name }
  end

  def pdf
    load_twitter_data(top_posts_limit: TOP_POSTS_PDF_LIMIT)
    load_profiles_data

    # Render with specific layout for PDF
    render layout: false
  end

  private

  def set_topic
    topic_id = params[:id] || params[:topic_id]
    @topic = Topic.find(topic_id)
  end

  def authorize_topic!
    return if @topic.status && @topic.users.exists?(current_user.id)

    redirect_to root_path,
                alert: 'El Tópico al que intentaste acceder no está asignado a tu usuario o se encuentra deshabilitado'
  end

  def parse_date_param
    Date.parse(params[:date]) if params[:date].present?
  rescue ArgumentError => e
    Rails.logger.warn "Invalid date parameter: #{params[:date]} - #{e.message}"
    nil
  end

  def load_twitter_data(top_posts_limit: TOP_POSTS_SHOW_LIMIT)
    @tag_list = @topic.tags.pluck(:name)
    @posts = TwitterPost.for_topic(@topic)
    @chart_posts = TwitterPost.grouped_counts(@posts)
    @chart_interactions = TwitterPost.grouped_interactions(@posts)

    @total_posts = @posts.size
    @total_interactions = TwitterPost.total_interactions(@posts)
    @total_views = TwitterPost.total_views(@posts)
    @average_interactions = @total_posts.zero? ? 0 : (Float(@total_interactions) / @total_posts).round(1)

    # Use database ORDER BY instead of Ruby sort - more efficient
    # Clear existing ordering first with reorder, then order by total interactions
    # Include quote_count to match the total_interactions instance method
    @top_posts = @posts.reorder(
      Arel.sql('(twitter_posts.favorite_count + twitter_posts.retweet_count + twitter_posts.reply_count + twitter_posts.quote_count) DESC')
    ).limit(top_posts_limit)

    @word_occurrences = TwitterPost.word_occurrences(@posts)
    @bigram_occurrences = TwitterPost.bigram_occurrences(@posts)

    @tag_counts = @posts.tag_counts_on(:tags).order(count: :desc).limit(TAG_LIMIT)

    @positive_words = @topic.positive_words.split(',') if @topic.positive_words.present?
    @negative_words = @topic.negative_words.split(',') if @topic.negative_words.present?

    load_tag_interactions
  end

  def load_tag_interactions
    # Use SQL aggregation instead of Ruby iteration for better performance
    # Need to clear default ordering to avoid conflicts with GROUP BY
    # Include quote_count to match the total_interactions instance method
    @tag_interactions = @posts.reorder(nil)
                              .joins(:tags)
                              .group('tags.name')
                              .sum(Arel.sql('twitter_posts.favorite_count + twitter_posts.retweet_count + twitter_posts.reply_count + twitter_posts.quote_count'))
                              .sort_by { |_, value| -value }
                              .to_h
  end

  def load_profiles_data
    profiles_group =
      @posts.includes(twitter_profile: :site).group_by do |post|
        post.twitter_profile&.name || 'Sin perfil'
      end
    
    @profiles_count = profiles_group.transform_values(&:size)
                                    .sort_by { |_, count| -count }
                                    .to_h
    
    @profiles_interactions = profiles_group.transform_values { |posts| posts.sum(&:total_interactions) }
                                           .sort_by { |_, value| -value }
                                           .to_h

    # Site data for media analysis
    @site_top_counts = @posts.joins(twitter_profile: :site)
                             .reorder(nil)
                             .group('sites.id')
                             .order(Arel.sql('COUNT(*) DESC'))
                             .limit(SITE_LIMIT)
                             .count
    
    @site_counts = @posts.joins(twitter_profile: :site)
                         .reorder(nil)
                         .group('sites.name')
                         .count
    
    @site_sums = @posts.joins(twitter_profile: :site)
                       .reorder(nil)
                       .group('sites.name')
                       .sum(Arel.sql('twitter_posts.favorite_count + twitter_posts.retweet_count + twitter_posts.reply_count + twitter_posts.quote_count'))
  end

  def load_twitter_temporal_intelligence
    begin
      @temporal_summary = @topic.twitter_temporal_intelligence_summary
      Rails.logger.info "✅ Twitter temporal_summary loaded successfully"
    rescue StandardError => e
      Rails.logger.error "❌ Error loading Twitter temporal_summary: #{e.class} - #{e.message}"
      @temporal_summary = nil
    end

    begin
      @optimal_time = @topic.twitter_optimal_publishing_time
      Rails.logger.info "✅ Twitter optimal_time loaded successfully"
    rescue StandardError => e
      Rails.logger.error "❌ Error loading Twitter optimal_time: #{e.class} - #{e.message}"
      @optimal_time = nil
    end

    begin
      @trend_velocity = @topic.twitter_trend_velocity
      Rails.logger.info "✅ Twitter trend_velocity loaded successfully"
    rescue StandardError => e
      Rails.logger.error "❌ Error loading Twitter trend_velocity: #{e.class} - #{e.message}"
      @trend_velocity = { velocity_percent: 0, direction: 'stable' }
    end

    begin
      @engagement_velocity = @topic.twitter_engagement_velocity
      Rails.logger.info "✅ Twitter engagement_velocity loaded successfully"
    rescue StandardError => e
      Rails.logger.error "❌ Error loading Twitter engagement_velocity: #{e.class} - #{e.message}"
      @engagement_velocity = { velocity_percent: 0, direction: 'stable' }
    end

    begin
      @content_half_life = @topic.twitter_content_half_life
      Rails.logger.info "✅ Twitter content_half_life loaded successfully"
    rescue StandardError => e
      Rails.logger.error "❌ Error loading Twitter content_half_life: #{e.class} - #{e.message}"
      @content_half_life = nil
    end

    begin
      @peak_hours = @topic.twitter_peak_publishing_times_by_hour
      Rails.logger.info "✅ Twitter peak_hours loaded successfully"
    rescue StandardError => e
      Rails.logger.error "❌ Error loading Twitter peak_hours: #{e.class} - #{e.message}"
      @peak_hours = {}
    end

    begin
      @peak_days = @topic.twitter_peak_publishing_times_by_day
      Rails.logger.info "✅ Twitter peak_days loaded successfully"
    rescue StandardError => e
      Rails.logger.error "❌ Error loading Twitter peak_days: #{e.class} - #{e.message}"
      @peak_days = {}
    end

    begin
      @heatmap_data = @topic.twitter_engagement_heatmap_data
      Rails.logger.info "✅ Twitter heatmap_data loaded successfully"
    rescue StandardError => e
      Rails.logger.error "❌ Error loading Twitter heatmap_data: #{e.class} - #{e.message}"
      @heatmap_data = []
    end
  end
end

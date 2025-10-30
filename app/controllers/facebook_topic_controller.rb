# frozen_string_literal: true

class FacebookTopicController < ApplicationController
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
    load_facebook_data
    load_pages_data
    load_facebook_temporal_intelligence
  end

  def entries_data
    date = parse_date_param || Date.current
    entries = FacebookEntry.for_topic(@topic, start_time: date.beginning_of_day, end_time: date.end_of_day)
                           .reorder(Arel.sql('(reactions_total_count + comments_count + share_count) DESC'))

    render partial: 'facebook_topic/chart_entries', locals: { entries:, entries_date: date, topic_name: @topic.name }
  end

  def pdf
    load_facebook_data(top_posts_limit: TOP_POSTS_PDF_LIMIT)
    load_pages_data

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

  def load_facebook_data(top_posts_limit: TOP_POSTS_SHOW_LIMIT)
    @tag_list = @topic.tags.pluck(:name)
    @entries = FacebookEntry.for_topic(@topic)
    @chart_posts = FacebookEntry.grouped_counts(@entries)
    @chart_interactions = FacebookEntry.grouped_interactions(@entries)

    @total_posts = @entries.size
    @total_interactions = FacebookEntry.total_interactions(@entries)
    @total_views = FacebookEntry.total_views(@entries)
    @average_interactions = @total_posts.zero? ? 0 : (Float(@total_interactions) / @total_posts).round(1)

    # Use database ORDER BY instead of Ruby sort - more efficient
    # Clear existing ordering first with reorder, then order by total interactions
    @top_posts = @entries.reorder(
      Arel.sql('(facebook_entries.reactions_total_count + facebook_entries.comments_count + facebook_entries.share_count) DESC')
    ).limit(top_posts_limit)

    @word_occurrences = FacebookEntry.word_occurrences(@entries)
    @bigram_occurrences = FacebookEntry.bigram_occurrences(@entries)

    @tag_counts = @entries.tag_counts_on(:tags).order(count: :desc).limit(TAG_LIMIT)

    @positive_words = @topic.positive_words.split(',') if @topic.positive_words.present?
    @negative_words = @topic.negative_words.split(',') if @topic.negative_words.present?

    load_tag_interactions
  end

  def load_tag_interactions
    # Use SQL aggregation instead of Ruby iteration for better performance
    # Need to clear default ordering to avoid conflicts with GROUP BY
    @tag_interactions = @entries.reorder(nil)
                                .joins(:tags)
                                .group('tags.name')
                                .sum(Arel.sql('facebook_entries.reactions_total_count + facebook_entries.comments_count + facebook_entries.share_count'))
                                .sort_by { |_, value| -value }
                                .to_h
  end

  def load_pages_data
    pages_group = @entries.includes(page: :site).group_by { |entry| entry.page&.name || 'Sin página' }
    
    @pages_count = pages_group.transform_values(&:size)
                              .sort_by { |_, count| -count }
                              .to_h
    
    @pages_interactions = pages_group.transform_values { |posts| posts.sum(&:total_interactions) }
                                     .sort_by { |_, value| -value }
                                     .to_h

    # Site data for media analysis
    @site_top_counts = @entries.joins(page: :site)
                               .reorder(nil)
                               .group('sites.id')
                               .order(Arel.sql('COUNT(*) DESC'))
                               .limit(SITE_LIMIT)
                               .count
    
    @site_counts = @entries.joins(page: :site)
                           .reorder(nil)
                           .group('sites.name')
                           .count
    
    @site_sums = @entries.joins(page: :site)
                         .reorder(nil)
                         .group('sites.name')
                         .sum(Arel.sql('facebook_entries.reactions_total_count + facebook_entries.comments_count + facebook_entries.share_count'))
  end

  def load_facebook_temporal_intelligence
    begin
      @temporal_summary = @topic.facebook_temporal_intelligence_summary
      Rails.logger.info "✅ Facebook temporal_summary loaded successfully"
    rescue StandardError => e
      Rails.logger.error "❌ Error loading Facebook temporal_summary: #{e.class} - #{e.message}"
      @temporal_summary = nil
    end

    begin
      @optimal_time = @topic.facebook_optimal_publishing_time
      Rails.logger.info "✅ Facebook optimal_time loaded successfully"
    rescue StandardError => e
      Rails.logger.error "❌ Error loading Facebook optimal_time: #{e.class} - #{e.message}"
      @optimal_time = nil
    end

    begin
      @trend_velocity = @topic.facebook_trend_velocity
      Rails.logger.info "✅ Facebook trend_velocity loaded successfully"
    rescue StandardError => e
      Rails.logger.error "❌ Error loading Facebook trend_velocity: #{e.class} - #{e.message}"
      @trend_velocity = { velocity_percent: 0, direction: 'stable' }
    end

    begin
      @engagement_velocity = @topic.facebook_engagement_velocity
      Rails.logger.info "✅ Facebook engagement_velocity loaded successfully"
    rescue StandardError => e
      Rails.logger.error "❌ Error loading Facebook engagement_velocity: #{e.class} - #{e.message}"
      @engagement_velocity = { velocity_percent: 0, direction: 'stable' }
    end

    begin
      @content_half_life = @topic.facebook_content_half_life
      Rails.logger.info "✅ Facebook content_half_life loaded successfully"
    rescue StandardError => e
      Rails.logger.error "❌ Error loading Facebook content_half_life: #{e.class} - #{e.message}"
      @content_half_life = nil
    end

    begin
      @peak_hours = @topic.facebook_peak_publishing_times_by_hour
      Rails.logger.info "✅ Facebook peak_hours loaded successfully"
    rescue StandardError => e
      Rails.logger.error "❌ Error loading Facebook peak_hours: #{e.class} - #{e.message}"
      @peak_hours = {}
    end

    begin
      @peak_days = @topic.facebook_peak_publishing_times_by_day
      Rails.logger.info "✅ Facebook peak_days loaded successfully"
    rescue StandardError => e
      Rails.logger.error "❌ Error loading Facebook peak_days: #{e.class} - #{e.message}"
      @peak_days = {}
    end

    begin
      @heatmap_data = @topic.facebook_engagement_heatmap_data
      Rails.logger.info "✅ Facebook heatmap_data loaded successfully"
    rescue StandardError => e
      Rails.logger.error "❌ Error loading Facebook heatmap_data: #{e.class} - #{e.message}"
      @heatmap_data = []
    end
  end
end

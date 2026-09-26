# frozen_string_literal: true

module InstagramDashboardServices
  # Service for aggregating Instagram dashboard data
  # Handles data loading, caching, and calculations for Instagram topic dashboards
  #
  # @example
  #   data = InstagramDashboardServices::AggregatorService.call(topic: @topic, top_posts_limit: 20)
  #   data[:instagram_data][:total_posts]  # => Total Instagram posts count
  #   data[:temporal_intelligence]         # => Temporal analysis data
  class AggregatorService < ApplicationService
    # Cache expiration time for dashboard data
    CACHE_EXPIRATION = 30.minutes

    def initialize(topic:, top_posts_limit: 20, days_range: DAYS_RANGE)
      @topic = topic
      @top_posts_limit = top_posts_limit
      @days_range = (days_range || DAYS_RANGE || 7).to_i # Default to 7 days if not provided
      @start_time = @days_range.days.ago.beginning_of_day
      @end_time = Time.zone.now.end_of_day
      @tags_data = @topic.tags.pluck(:id, :name)
      @tag_ids = @tags_data.map(&:first)
      @tag_names = @tags_data.map(&:last)
      @instagram_data_cache = nil # Memoization
    end

    def call
      snapshot =
        fetch_cached_with_race_protection(cache_key, expires_in: CACHE_EXPIRATION) do
          build_dashboard_snapshot
        end

      attach_post_relations(snapshot)
    end

    private

    def cache_key
      "instagram_dashboard:v4:topic:#{@topic.id}:limit:#{@top_posts_limit}:payload:#{cache_date_range}"
    end

    def cache_date_range
      "#{@start_time.to_date.iso8601}:#{@end_time.to_date.iso8601}"
    end

    def build_dashboard_snapshot
      {
        instagram_data: instagram_data.except(:posts, :top_posts),
        profiles_data: load_profiles_data,
        temporal_intelligence: load_temporal_intelligence,
        viral_content: detect_viral_content
      }
    end

    def attach_post_relations(snapshot)
      posts = instagram_posts

      snapshot.merge(instagram_data: snapshot.fetch(:instagram_data).merge(posts: posts, top_posts: top_posts(posts)))
    end

    # Memoized instagram data to avoid reloading posts multiple times
    def instagram_data
      @instagram_data_cache ||= load_instagram_data
    end

    def instagram_posts
      @instagram_posts ||= InstagramPost.for_topic(
        @topic,
        start_time: @start_time,
        end_time: @end_time,
        tag_ids: @tag_ids
      )
    end

    def load_instagram_data
      return empty_instagram_data if @tag_names.empty?

      # Single base query with all necessary includes
      posts = instagram_posts

      # Execute aggregations efficiently
      chart_data = calculate_chart_data(posts)
      statistics = calculate_statistics(posts)
      text_analysis = calculate_text_analysis(posts)
      tag_data = calculate_tag_data(posts)

      {
        tag_list: @tag_names,
        posts: posts,
        **chart_data,
        **statistics,
        **text_analysis,
        **tag_data
      }
    end

    def calculate_chart_data(posts)
      {
        chart_posts: InstagramPost.grouped_counts(posts),
        chart_interactions: InstagramPost.grouped_interactions(posts)
      }
    end

    def calculate_statistics(posts)
      total_posts, total_interactions, total_views = posts.except(:includes).reorder(nil).pluck(
        Arel.sql('COUNT(*)'),
        Arel.sql('COALESCE(SUM(instagram_posts.likes_count + instagram_posts.comments_count), 0)'),
        Arel.sql('COALESCE(SUM(instagram_posts.video_view_count), 0)')
      ).first || [0, 0, 0]

      # Safe division
      average_interactions = total_posts.zero? ? 0 : (total_interactions.to_f / total_posts).round(1)

      {
        total_posts: total_posts,
        total_interactions: total_interactions,
        total_views: total_views,
        average_interactions: average_interactions,
        top_posts: top_posts(posts)
      }
    end

    # Use database ORDER BY for efficiency (single query)
    # Instagram: likes_count + comments_count
    def top_posts(posts)
      posts.reorder(
        Arel.sql('(instagram_posts.likes_count + instagram_posts.comments_count) DESC')
      ).limit(@top_posts_limit)
    end

    def calculate_text_analysis(posts)
      InstagramPost.text_occurrences(posts).merge(
        positive_words: parse_word_list(@topic.positive_words),
        negative_words: parse_word_list(@topic.negative_words)
      )
    end

    def calculate_tag_data(posts)
      tag_counts = posts.tag_counts_on(:tags).order(count: :desc).limit(20)

      # Single query for tag interactions
      # Instagram: likes + comments
      tag_interactions = posts.reorder(nil)
                              .joins(:tags)
                              .group('tags.name')
                              .sum(Arel.sql('instagram_posts.likes_count + instagram_posts.comments_count'))
                              .sort_by { |_, value| -value }
                              .to_h

      {
        tag_counts: tag_counts,
        tag_interactions: tag_interactions
      }
    end

    def load_profiles_data
      posts = instagram_data[:posts]
      return empty_profiles_data if posts.empty?

      profiles_data = calculate_profiles_metrics(posts)
      site_data = calculate_site_metrics(posts)

      profiles_data.merge(site_data)
    end

    def calculate_profiles_metrics(posts)
      rows = posts.except(:includes).reorder(nil).left_joins(:instagram_profile).group('instagram_profiles.id', 'instagram_profiles.full_name', 'instagram_profiles.username').pluck(
        Arel.sql('instagram_profiles.id'),
        Arel.sql('instagram_profiles.full_name'),
        Arel.sql('instagram_profiles.username'),
        Arel.sql('COUNT(*)'),
        Arel.sql('COALESCE(SUM(instagram_posts.likes_count + instagram_posts.comments_count), 0)')
      )
      profiles_by_id = InstagramProfile.where(id: rows.map(&:first).compact).includes(:site).index_by(&:id)
      profiles_count = rows
                       .map do |id, full_name, username, count, _|
                         { profile: profiles_by_id[id], name: full_name || username || 'Sin perfil', count: count }
                       end
                       .sort_by { |data| -data[:count] }
      profiles_interactions = rows
                              .map do |id, full_name, username, _, interactions|
                                {
                                  profile: profiles_by_id[id],
                                  name: full_name || username || 'Sin perfil',
                                  interactions: interactions
                                }
                              end
                              .sort_by { |data| -data[:interactions] }

      {
        profiles_count: profiles_count,
        profiles_interactions: profiles_interactions
      }
    end

    def calculate_site_metrics(posts)
      rows = posts.except(:includes).joins(instagram_profile: :site).reorder(nil).group('sites.id', 'sites.name').pluck(
        Arel.sql('sites.id'),
        Arel.sql('sites.name'),
        Arel.sql('COUNT(*)'),
        Arel.sql('COALESCE(SUM(instagram_posts.likes_count + instagram_posts.comments_count), 0)')
      )
      site_top_counts = rows.sort_by { |_, _, count, _| -count }
                            .first(12).to_h { |id, _, count, _| [id, count] }
      site_counts = rows.to_h { |_, name, count, _| [name, count] }
      site_sums = rows.to_h { |_, name, _, interactions| [name, interactions] }

      {
        site_top_counts: site_top_counts,
        site_counts: site_counts,
        site_sums: site_sums
      }
    end

    def load_temporal_intelligence
      {
        temporal_summary: safe_call { @topic.instagram_temporal_intelligence_summary },
        optimal_time: safe_call { @topic.instagram_optimal_publishing_time },
        trend_velocity: safe_call { @topic.instagram_trend_velocity } || default_velocity,
        engagement_velocity: safe_call { @topic.instagram_engagement_velocity } || default_velocity,
        content_half_life: safe_call { @topic.instagram_content_half_life },
        peak_hours: safe_call { @topic.instagram_peak_publishing_times_by_hour } || {},
        peak_days: safe_call { @topic.instagram_peak_publishing_times_by_day } || {},
        heatmap_data: safe_call { @topic.instagram_engagement_heatmap_data } || []
      }
    end

    # Helper methods

    def parse_word_list(word_string)
      word_string.present? ? word_string.split(',').map(&:strip) : []
    end

    def safe_call
      yield
    rescue StandardError => e
      Rails.logger.error "Error in InstagramDashboardServices: #{e.class} - #{e.message}"
      Rails.logger.error e.backtrace.first(5).join("\n")
      nil
    end

    # Default values for missing data

    def default_velocity
      { velocity_percent: 0, direction: 'stable' }
    end

    def empty_instagram_data
      {
        tag_list: [],
        posts: InstagramPost.none,
        chart_posts: {},
        chart_interactions: {},
        total_posts: 0,
        total_interactions: 0,
        total_views: 0,
        average_interactions: 0,
        top_posts: [],
        word_occurrences: {},
        bigram_occurrences: {},
        tag_counts: [],
        positive_words: [],
        negative_words: [],
        tag_interactions: {}
      }
    end

    def empty_profiles_data
      {
        profiles_count: [],
        profiles_interactions: [],
        site_top_counts: {},
        site_counts: {},
        site_sums: {}
      }
    end

    # ========================================
    # VIRAL CONTENT DETECTION
    # ========================================
    def detect_viral_content
      return [] if @tag_names.empty?

      # Get Instagram posts from last 24 hours
      recent_posts = InstagramPost.for_topic(@topic, start_time: 24.hours.ago, end_time: Time.current)
                                  .includes(:instagram_profile)

      # Use .to_a.size instead of .count to avoid SQL issues with acts_as_taggable_on
      posts_array = recent_posts.to_a
      return [] if posts_array.empty?

      # Calculate baseline for comparison (median of non-zero values, or 1 if none)
      engagement_values = posts_array.map(&:total_interactions)
      non_zero_values = engagement_values.select { |v| v > 0 }

      baseline =
        if non_zero_values.size >= 3
          # Use median of non-zero values if we have enough data
          sorted = non_zero_values.sort
          calculate_median(sorted)
        elsif non_zero_values.any?
          # Use average of non-zero values if we have 1-2 values
          non_zero_values.sum / non_zero_values.size.to_f
        else
          # All zeros, use 1 to avoid division by zero
          1.0
        end

      # Dynamic threshold: Content is viral if it's 5x above median OR has >50 interactions
      # This adapts to the topic's typical engagement levels
      dynamic_threshold = [baseline * 5, 50].min

      # Get viral posts
      viral_posts = posts_array.select { |p| p.total_interactions > dynamic_threshold }
                               .sort_by { |p| -p.total_interactions }
                               .take(10)

      return [] if viral_posts.empty?

      viral_posts.map do |post|
        {
          post: post,
          multiplier: (post.total_interactions / baseline).round(1),
          engagement: post.total_interactions,
          posted_at: post.posted_at
        }
      end
    end

    def calculate_median(sorted_array)
      size = sorted_array.size
      if size.odd?
        sorted_array[size / 2].to_f
      else
        (sorted_array[(size / 2) - 1] + sorted_array[size / 2]) / 2.0
      end
    end
  end
end

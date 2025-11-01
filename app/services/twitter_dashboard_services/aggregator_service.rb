# frozen_string_literal: true

module TwitterDashboardServices
  # Service for aggregating Twitter dashboard data
  # Handles data loading, caching, and calculations for Twitter topic dashboards
  #
  # @example
  #   data = TwitterDashboardServices::AggregatorService.call(topic: @topic, top_posts_limit: 20)
  #   data[:twitter_data][:total_posts]  # => Total Twitter posts count
  #   data[:temporal_intelligence]        # => Temporal analysis data
  class AggregatorService < ApplicationService
    # Cache expiration time for dashboard data
    CACHE_EXPIRATION = 1.hour

    def initialize(topic:, top_posts_limit: 20)
      @topic = topic
      @top_posts_limit = top_posts_limit
      @tag_names = @topic.tags.pluck(:name) # Cache tag names
      @twitter_data_cache = nil # Memoization
    end

    def call
      Rails.cache.fetch(cache_key, expires_in: CACHE_EXPIRATION) do
        {
          twitter_data: twitter_data,
          profiles_data: load_profiles_data,
          temporal_intelligence: load_temporal_intelligence
        }
      end
    end

    private

    def cache_key
      "twitter_dashboard_#{@topic.id}_#{@top_posts_limit}_#{Date.current}"
    end

    # Memoized twitter data to avoid reloading posts multiple times
    def twitter_data
      @twitter_data_cache ||= load_twitter_data
    end

    def load_twitter_data
      return empty_twitter_data if @tag_names.empty?

      # Single base query with all necessary includes
      posts = TwitterPost.for_topic(@topic)
      
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
        chart_posts: TwitterPost.grouped_counts(posts),
        chart_interactions: TwitterPost.grouped_interactions(posts)
      }
    end

    def calculate_statistics(posts)
      total_posts = posts.size
      total_interactions = TwitterPost.total_interactions(posts)
      total_views = TwitterPost.total_views(posts)
      
      # Safe division
      average_interactions = total_posts.zero? ? 0 : (total_interactions.to_f / total_posts).round(1)

      # Use database ORDER BY for efficiency (single query)
      top_posts = posts.reorder(
        Arel.sql('(twitter_posts.favorite_count + twitter_posts.retweet_count + twitter_posts.reply_count + twitter_posts.quote_count) DESC')
      ).limit(@top_posts_limit)

      {
        total_posts: total_posts,
        total_interactions: total_interactions,
        total_views: total_views,
        average_interactions: average_interactions,
        top_posts: top_posts
      }
    end

    def calculate_text_analysis(posts)
      {
        word_occurrences: TwitterPost.word_occurrences(posts),
        bigram_occurrences: TwitterPost.bigram_occurrences(posts),
        positive_words: parse_word_list(@topic.positive_words),
        negative_words: parse_word_list(@topic.negative_words)
      }
    end

    def calculate_tag_data(posts)
      tag_counts = posts.tag_counts_on(:tags).order(count: :desc).limit(20)

      # Single query for tag interactions
      tag_interactions = posts.reorder(nil)
                              .joins(:tags)
                              .group('tags.name')
                              .sum(Arel.sql('twitter_posts.favorite_count + twitter_posts.retweet_count + twitter_posts.reply_count + twitter_posts.quote_count'))
                              .sort_by { |_, value| -value }
                              .to_h

      {
        tag_counts: tag_counts,
        tag_interactions: tag_interactions
      }
    end

    def load_profiles_data
      posts = twitter_data[:posts]
      return empty_profiles_data if posts.empty?

      # Load all posts with associations in one query
      loaded_posts = posts.includes(twitter_profile: :site).to_a

      # Group in memory (more efficient than multiple queries)
      profiles_group = loaded_posts.group_by { |post| post.twitter_profile&.name || 'Sin perfil' }

      # Calculate metrics in one pass
      profiles_data = calculate_profiles_metrics(profiles_group)
      site_data = calculate_site_metrics(posts)

      profiles_data.merge(site_data)
    end

    def calculate_profiles_metrics(profiles_group)
      profiles_count = profiles_group.transform_values(&:size)
                                     .sort_by { |_, count| -count }
                                     .to_h

      profiles_interactions = profiles_group.transform_values { |posts| posts.sum(&:total_interactions) }
                                            .sort_by { |_, value| -value }
                                            .to_h

      {
        profiles_count: profiles_count,
        profiles_interactions: profiles_interactions
      }
    end

    def calculate_site_metrics(posts)
      # Batch site queries for efficiency
      base_query = posts.joins(twitter_profile: :site).reorder(nil)

      site_top_counts = base_query.group('sites.id')
                                  .order(Arel.sql('COUNT(*) DESC'))
                                  .limit(12)
                                  .count

      site_counts = base_query.group('sites.name').count
      
      site_sums = base_query.group('sites.name')
                            .sum(Arel.sql('twitter_posts.favorite_count + twitter_posts.retweet_count + twitter_posts.reply_count + twitter_posts.quote_count'))

      {
        site_top_counts: site_top_counts,
        site_counts: site_counts,
        site_sums: site_sums
      }
    end

    def load_temporal_intelligence
      {
        temporal_summary: safe_call { @topic.twitter_temporal_intelligence_summary },
        optimal_time: safe_call { @topic.twitter_optimal_publishing_time },
        trend_velocity: safe_call { @topic.twitter_trend_velocity } || default_velocity,
        engagement_velocity: safe_call { @topic.twitter_engagement_velocity } || default_velocity,
        content_half_life: safe_call { @topic.twitter_content_half_life },
        peak_hours: safe_call { @topic.twitter_peak_publishing_times_by_hour } || {},
        peak_days: safe_call { @topic.twitter_peak_publishing_times_by_day } || {},
        heatmap_data: safe_call { @topic.twitter_engagement_heatmap_data } || []
      }
    end

    # Helper methods

    def parse_word_list(word_string)
      word_string.present? ? word_string.split(',').map(&:strip) : []
    end

    def safe_call
      yield
    rescue StandardError => e
      Rails.logger.error "Error in TwitterDashboardServices: #{e.class} - #{e.message}"
      Rails.logger.error e.backtrace.first(5).join("\n")
      nil
    end

    # Default values for missing data

    def default_velocity
      { velocity_percent: 0, direction: 'stable' }
    end

    def empty_twitter_data
      {
        tag_list: [],
        posts: TwitterPost.none,
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
        profiles_count: {},
        profiles_interactions: {},
        site_top_counts: {},
        site_counts: {},
        site_sums: {}
      }
    end
  end
end

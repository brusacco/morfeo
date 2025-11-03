# frozen_string_literal: true

module FacebookDashboardServices
  # Service for aggregating Facebook dashboard data
  # Handles data loading, caching, and calculations for Facebook topic dashboards
  #
  # @example
  #   data = FacebookDashboardServices::AggregatorService.call(topic: @topic, top_posts_limit: 20)
  #   data[:facebook_data][:total_posts]  # => Total Facebook posts count
  #   data[:sentiment_analysis]           # => Sentiment analysis data
  class AggregatorService < ApplicationService
    # Cache expiration time for dashboard data
    CACHE_EXPIRATION = 30.minutes

    def initialize(topic:, top_posts_limit: 20)
      @topic = topic
      @top_posts_limit = top_posts_limit
      @tag_names = @topic.tags.pluck(:name) # Cache tag names
      @facebook_data_cache = nil # Memoization
    end

    def call
      Rails.cache.fetch(cache_key, expires_in: CACHE_EXPIRATION) do
        {
          facebook_data: facebook_data,
          pages_data: load_pages_data,
          temporal_intelligence: load_temporal_intelligence,
          sentiment_analysis: load_sentiment_analysis
        }
      end
    end

    private

    def cache_key
      "facebook_dashboard_#{@topic.id}_#{@top_posts_limit}_#{Date.current}"
    end

    # Memoized facebook data to avoid reloading entries multiple times
    def facebook_data
      @facebook_data_cache ||= load_facebook_data
    end

    def load_facebook_data
      return empty_facebook_data if @tag_names.empty?

      # Single base query with all necessary includes
      entries = FacebookEntry.for_topic(@topic)
      
      # Execute aggregations efficiently
      chart_data = calculate_chart_data(entries)
      statistics = calculate_statistics(entries)
      text_analysis = calculate_text_analysis(entries)
      tag_data = calculate_tag_data(entries)

      {
        tag_list: @tag_names,
        entries: entries,
        **chart_data,
        **statistics,
        **text_analysis,
        **tag_data
      }
    end

    def calculate_chart_data(entries)
      {
        chart_posts: FacebookEntry.grouped_counts(entries),
        chart_interactions: FacebookEntry.grouped_interactions(entries)
      }
    end

    def calculate_statistics(entries)
      total_posts = entries.size
      total_interactions = FacebookEntry.total_interactions(entries)
      total_views = FacebookEntry.total_views(entries)
      
      # Safe division
      average_interactions = total_posts.zero? ? 0 : (total_interactions.to_f / total_posts).round(1)

      # Use database ORDER BY for efficiency (single query)
      top_posts = entries.reorder(
        Arel.sql('(facebook_entries.reactions_total_count + facebook_entries.comments_count + facebook_entries.share_count) DESC')
      ).limit(@top_posts_limit)

      {
        total_posts: total_posts,
        total_interactions: total_interactions,
        total_views: total_views,
        average_interactions: average_interactions,
        top_posts: top_posts
      }
    end

    def calculate_text_analysis(entries)
      {
        word_occurrences: FacebookEntry.word_occurrences(entries),
        bigram_occurrences: FacebookEntry.bigram_occurrences(entries),
        positive_words: parse_word_list(@topic.positive_words),
        negative_words: parse_word_list(@topic.negative_words)
      }
    end

    def calculate_tag_data(entries)
      tag_counts = entries.tag_counts_on(:tags).order(count: :desc).limit(20)

      # Single query for tag interactions
      tag_interactions = entries.reorder(nil)
                                .joins(:tags)
                                .group('tags.name')
                                .sum(Arel.sql('facebook_entries.reactions_total_count + facebook_entries.comments_count + facebook_entries.share_count'))
                                .sort_by { |_, value| -value }
                                .to_h

      {
        tag_counts: tag_counts,
        tag_interactions: tag_interactions
      }
    end

    def load_pages_data
      entries = facebook_data[:entries]
      return empty_pages_data if entries.empty?

      # Load all entries with associations in one query
      loaded_entries = entries.includes(page: :site).to_a

      # Group in memory (more efficient than multiple queries)
      pages_group = loaded_entries.group_by { |entry| entry.page&.name || 'Sin página' }

      # Calculate metrics in one pass
      pages_data = calculate_pages_metrics(pages_group)
      site_data = calculate_site_metrics(entries)

      pages_data.merge(site_data)
    end

    def calculate_pages_metrics(pages_group)
      pages_count = pages_group.transform_values(&:size)
                               .sort_by { |_, count| -count }
                               .to_h

      pages_interactions = pages_group.transform_values { |posts| posts.sum(&:total_interactions) }
                                      .sort_by { |_, value| -value }
                                      .to_h

      {
        pages_count: pages_count,
        pages_interactions: pages_interactions
      }
    end

    def calculate_site_metrics(entries)
      # Batch site queries for efficiency
      base_query = entries.joins(page: :site).reorder(nil)

      site_top_counts = base_query.group('sites.id')
                                  .order(Arel.sql('COUNT(*) DESC'))
                                  .limit(12)
                                  .count

      site_counts = base_query.group('sites.name').count
      
      site_sums = base_query.group('sites.name')
                            .sum(Arel.sql('facebook_entries.reactions_total_count + facebook_entries.comments_count + facebook_entries.share_count'))

      {
        site_top_counts: site_top_counts,
        site_counts: site_counts,
        site_sums: site_sums
      }
    end

    def load_temporal_intelligence
      {
        temporal_summary: safe_call { @topic.facebook_temporal_intelligence_summary },
        optimal_time: safe_call { @topic.facebook_optimal_publishing_time },
        trend_velocity: safe_call { @topic.facebook_trend_velocity } || default_velocity,
        engagement_velocity: safe_call { @topic.facebook_engagement_velocity } || default_velocity,
        content_half_life: safe_call { @topic.facebook_content_half_life },
        peak_hours: safe_call { @topic.facebook_peak_publishing_times_by_hour } || {},
        peak_days: safe_call { @topic.facebook_peak_publishing_times_by_day } || {},
        heatmap_data: safe_call { @topic.facebook_engagement_heatmap_data } || []
      }
    end

    def load_sentiment_analysis
      sentiment_summary = safe_call { @topic.facebook_sentiment_summary }

      result = extract_sentiment_data(sentiment_summary)
      
      result[:sentiment_trend] = safe_call { @topic.facebook_sentiment_trend } || default_sentiment_trend
      result[:sentiment_summary] = sentiment_summary

      result
    end

    def extract_sentiment_data(sentiment_summary)
      return {} unless sentiment_summary

      {
        sentiment_distribution: sentiment_summary[:sentiment_distribution],
        sentiment_over_time: sentiment_summary[:sentiment_over_time],
        reaction_breakdown: sentiment_summary[:reaction_breakdown],
        top_positive_posts: sentiment_summary[:top_positive_posts],
        top_negative_posts: sentiment_summary[:top_negative_posts],
        controversial_posts: sentiment_summary[:controversial_posts],
        emotional_trends: sentiment_summary[:emotional_trends]
      }
    end

    # Helper methods

    def parse_word_list(word_string)
      word_string.present? ? word_string.split(',').map(&:strip) : []
    end

    def safe_call
      yield
    rescue StandardError => e
      Rails.logger.error "Error in FacebookDashboardServices: #{e.class} - #{e.message}"
      Rails.logger.error e.backtrace.first(5).join("\n")
      nil
    end

    # Default values for missing data

    def default_velocity
      { velocity_percent: 0, direction: 'stable' }
    end

    def default_sentiment_trend
      {
        trend: 'stable',
        change_percent: 0.0,
        recent_score: 0.0,
        previous_score: 0.0,
        direction: 'stable'
      }
    end

    def empty_facebook_data
      {
        tag_list: [],
        entries: FacebookEntry.none,
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

    def empty_pages_data
      {
        pages_count: {},
        pages_interactions: {},
        site_top_counts: {},
        site_counts: {},
        site_sums: {}
      }
    end
  end
end

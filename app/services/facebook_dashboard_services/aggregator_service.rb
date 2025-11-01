# frozen_string_literal: true

module FacebookDashboardServices
  class AggregatorService < ApplicationService
    def initialize(topic:, top_posts_limit: 20)
      @topic = topic
      @top_posts_limit = top_posts_limit
    end

    def call
      Rails.cache.fetch(cache_key, expires_in: 1.hour) do
        {
          facebook_data: load_facebook_data,
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

    def load_facebook_data
      tag_list = @topic.tags.pluck(:name)
      entries = FacebookEntry.for_topic(@topic)
      chart_posts = FacebookEntry.grouped_counts(entries)
      chart_interactions = FacebookEntry.grouped_interactions(entries)

      total_posts = entries.size
      total_interactions = FacebookEntry.total_interactions(entries)
      total_views = FacebookEntry.total_views(entries)
      average_interactions = total_posts.zero? ? 0 : (Float(total_interactions) / total_posts).round(1)

      # Use database ORDER BY instead of Ruby sort - more efficient
      top_posts = entries.reorder(
        Arel.sql('(facebook_entries.reactions_total_count + facebook_entries.comments_count + facebook_entries.share_count) DESC')
      ).limit(@top_posts_limit)

      word_occurrences = FacebookEntry.word_occurrences(entries)
      bigram_occurrences = FacebookEntry.bigram_occurrences(entries)

      tag_counts = entries.tag_counts_on(:tags).order(count: :desc).limit(20)

      positive_words = @topic.positive_words.split(',') if @topic.positive_words.present?
      negative_words = @topic.negative_words.split(',') if @topic.negative_words.present?

      # Tag interactions
      tag_interactions = entries.reorder(nil)
                                .joins(:tags)
                                .group('tags.name')
                                .sum(Arel.sql('facebook_entries.reactions_total_count + facebook_entries.comments_count + facebook_entries.share_count'))
                                .sort_by { |_, value| -value }
                                .to_h

      {
        tag_list: tag_list,
        entries: entries,
        chart_posts: chart_posts,
        chart_interactions: chart_interactions,
        total_posts: total_posts,
        total_interactions: total_interactions,
        total_views: total_views,
        average_interactions: average_interactions,
        top_posts: top_posts,
        word_occurrences: word_occurrences,
        bigram_occurrences: bigram_occurrences,
        tag_counts: tag_counts,
        positive_words: positive_words,
        negative_words: negative_words,
        tag_interactions: tag_interactions
      }
    end

    def load_pages_data
      entries = FacebookEntry.for_topic(@topic)
      pages_group = entries.includes(page: :site).group_by { |entry| entry.page&.name || 'Sin página' }

      pages_count = pages_group.transform_values(&:size)
                               .sort_by { |_, count| -count }
                               .to_h

      pages_interactions = pages_group.transform_values { |posts| posts.sum(&:total_interactions) }
                                      .sort_by { |_, value| -value }
                                      .to_h

      # Site data for media analysis
      site_top_counts = entries.joins(page: :site)
                               .reorder(nil)
                               .group('sites.id')
                               .order(Arel.sql('COUNT(*) DESC'))
                               .limit(12)
                               .count

      site_counts = entries.joins(page: :site)
                           .reorder(nil)
                           .group('sites.name')
                           .count

      site_sums = entries.joins(page: :site)
                         .reorder(nil)
                         .group('sites.name')
                         .sum(Arel.sql('facebook_entries.reactions_total_count + facebook_entries.comments_count + facebook_entries.share_count'))

      {
        pages_count: pages_count,
        pages_interactions: pages_interactions,
        site_top_counts: site_top_counts,
        site_counts: site_counts,
        site_sums: site_sums
      }
    end

    def load_temporal_intelligence
      {
        temporal_summary: safe_call { @topic.facebook_temporal_intelligence_summary },
        optimal_time: safe_call { @topic.facebook_optimal_publishing_time },
        trend_velocity: safe_call { @topic.facebook_trend_velocity } || { velocity_percent: 0, direction: 'stable' },
        engagement_velocity: safe_call { @topic.facebook_engagement_velocity } || { velocity_percent: 0, direction: 'stable' },
        content_half_life: safe_call { @topic.facebook_content_half_life },
        peak_hours: safe_call { @topic.facebook_peak_publishing_times_by_hour } || {},
        peak_days: safe_call { @topic.facebook_peak_publishing_times_by_day } || {},
        heatmap_data: safe_call { @topic.facebook_engagement_heatmap_data } || []
      }
    end

    def load_sentiment_analysis
      sentiment_summary = safe_call { @topic.facebook_sentiment_summary }

      result = {}

      if sentiment_summary
        result[:sentiment_distribution] = sentiment_summary[:sentiment_distribution]
        result[:sentiment_over_time] = sentiment_summary[:sentiment_over_time]
        result[:reaction_breakdown] = sentiment_summary[:reaction_breakdown]
        result[:top_positive_posts] = sentiment_summary[:top_positive_posts]
        result[:top_negative_posts] = sentiment_summary[:top_negative_posts]
        result[:controversial_posts] = sentiment_summary[:controversial_posts]
        result[:emotional_trends] = sentiment_summary[:emotional_trends]
      end

      result[:sentiment_trend] = safe_call { @topic.facebook_sentiment_trend } || {
        trend: 'stable',
        change_percent: 0.0,
        recent_score: 0.0,
        previous_score: 0.0,
        direction: 'stable'
      }

      result[:sentiment_summary] = sentiment_summary

      result
    end

    def safe_call
      yield
    rescue StandardError => e
      Rails.logger.error "Error in FacebookDashboardServices: #{e.class} - #{e.message}"
      Rails.logger.error e.backtrace.first(5).join("\n")
      nil
    end
  end
end


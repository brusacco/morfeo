# frozen_string_literal: true

module TwitterDashboardServices
  class AggregatorService < ApplicationService
    def initialize(topic:, top_posts_limit: 20)
      @topic = topic
      @top_posts_limit = top_posts_limit
    end

    def call
      Rails.cache.fetch(cache_key, expires_in: 1.hour) do
        {
          twitter_data: load_twitter_data,
          profiles_data: load_profiles_data,
          temporal_intelligence: load_temporal_intelligence
        }
      end
    end

    private

    def cache_key
      "twitter_dashboard_#{@topic.id}_#{@top_posts_limit}_#{Date.current}"
    end

    def load_twitter_data
      tag_list = @topic.tags.pluck(:name)
      posts = TwitterPost.for_topic(@topic)
      chart_posts = TwitterPost.grouped_counts(posts)
      chart_interactions = TwitterPost.grouped_interactions(posts)

      total_posts = posts.size
      total_interactions = TwitterPost.total_interactions(posts)
      total_views = TwitterPost.total_views(posts)
      average_interactions = total_posts.zero? ? 0 : (Float(total_interactions) / total_posts).round(1)

      # Use database ORDER BY instead of Ruby sort - more efficient
      top_posts = posts.reorder(
        Arel.sql('(twitter_posts.favorite_count + twitter_posts.retweet_count + twitter_posts.reply_count + twitter_posts.quote_count) DESC')
      ).limit(@top_posts_limit)

      word_occurrences = TwitterPost.word_occurrences(posts)
      bigram_occurrences = TwitterPost.bigram_occurrences(posts)

      tag_counts = posts.tag_counts_on(:tags).order(count: :desc).limit(20)

      positive_words = @topic.positive_words.split(',') if @topic.positive_words.present?
      negative_words = @topic.negative_words.split(',') if @topic.negative_words.present?

      # Tag interactions
      tag_interactions = posts.reorder(nil)
                              .joins(:tags)
                              .group('tags.name')
                              .sum(Arel.sql('twitter_posts.favorite_count + twitter_posts.retweet_count + twitter_posts.reply_count + twitter_posts.quote_count'))
                              .sort_by { |_, value| -value }
                              .to_h

      {
        tag_list: tag_list,
        posts: posts,
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

    def load_profiles_data
      posts = TwitterPost.for_topic(@topic)
      profiles_group = posts.includes(twitter_profile: :site).group_by do |post|
        post.twitter_profile&.name || 'Sin perfil'
      end

      profiles_count = profiles_group.transform_values(&:size)
                                     .sort_by { |_, count| -count }
                                     .to_h

      profiles_interactions = profiles_group.transform_values { |posts| posts.sum(&:total_interactions) }
                                            .sort_by { |_, value| -value }
                                            .to_h

      # Site data for media analysis
      site_top_counts = posts.joins(twitter_profile: :site)
                             .reorder(nil)
                             .group('sites.id')
                             .order(Arel.sql('COUNT(*) DESC'))
                             .limit(12)
                             .count

      site_counts = posts.joins(twitter_profile: :site)
                         .reorder(nil)
                         .group('sites.name')
                         .count

      site_sums = posts.joins(twitter_profile: :site)
                       .reorder(nil)
                       .group('sites.name')
                       .sum(Arel.sql('twitter_posts.favorite_count + twitter_posts.retweet_count + twitter_posts.reply_count + twitter_posts.quote_count'))

      {
        profiles_count: profiles_count,
        profiles_interactions: profiles_interactions,
        site_top_counts: site_top_counts,
        site_counts: site_counts,
        site_sums: site_sums
      }
    end

    def load_temporal_intelligence
      {
        temporal_summary: safe_call { @topic.twitter_temporal_intelligence_summary },
        optimal_time: safe_call { @topic.twitter_optimal_publishing_time },
        trend_velocity: safe_call { @topic.twitter_trend_velocity } || { velocity_percent: 0, direction: 'stable' },
        engagement_velocity: safe_call { @topic.twitter_engagement_velocity } || { velocity_percent: 0, direction: 'stable' },
        content_half_life: safe_call { @topic.twitter_content_half_life },
        peak_hours: safe_call { @topic.twitter_peak_publishing_times_by_hour } || {},
        peak_days: safe_call { @topic.twitter_peak_publishing_times_by_day } || {},
        heatmap_data: safe_call { @topic.twitter_engagement_heatmap_data } || []
      }
    end

    def safe_call
      yield
    rescue StandardError => e
      Rails.logger.error "Error in TwitterDashboardServices: #{e.class} - #{e.message}"
      Rails.logger.error e.backtrace.first(5).join("\n")
      nil
    end
  end
end


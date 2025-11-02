# frozen_string_literal: true

module DigitalDashboardServices
  # Service for aggregating digital dashboard data
  # Handles data loading, caching, and calculations for digital topic dashboards
  #
  # @example
  #   data = DigitalDashboardServices::AggregatorService.call(topic: @topic)
  #   data[:topic_data][:total_entries]  # => Total entries count
  class AggregatorService < ApplicationService
    # Cache expiration time for dashboard data
    CACHE_EXPIRATION = 1.hour
    
    def initialize(topic:, days_range: DAYS_RANGE)
      @topic = topic
      @days_range = days_range
      @start_date = days_range.days.ago.beginning_of_day
      @end_date = Time.current
      @tag_names = @topic.tags.pluck(:name) # Cache tag names
      @topic_data_cache = nil # Memoization
    end

    def call
      Rails.cache.fetch(cache_key, expires_in: CACHE_EXPIRATION) do
        {
          topic_data: topic_data,
          chart_data: load_chart_data,
          percentages: calculate_percentages,
          tags_and_words: load_tags_and_word_data,
          temporal_intelligence: load_temporal_intelligence
        }
      end
    end

    private

    def cache_key
      "digital_dashboard_#{@topic.id}_#{@days_range}_#{Date.current}"
    end

    # Memoized topic data to avoid multiple loads
    def topic_data
      @topic_data_cache ||= load_topic_data
    end

    def load_topic_data
      return empty_topic_data if @tag_names.empty?

      entries = @topic.list_entries

      # Batch all aggregations in single pass
      aggregations = calculate_entry_aggregations(entries)

      # Cache expensive site queries
      site_data = calculate_site_data(entries)

      {
        tag_list: @tag_names,
        entries: entries,
        **aggregations,
        **site_data
      }
    end

    def calculate_entry_aggregations(entries)
      # Precompute aggregates to avoid multiple SQL queries
      # IMPORTANT: Use distinct to avoid counting duplicates from joins
      entries_count = entries.distinct.count
      entries_total_sum = entries.distinct.sum(:total_count)

      # Combine polarity aggregations into a single query
      # Use reorder(nil) to remove any existing ORDER BY before GROUP BY
      # Use DISTINCT to avoid duplicate rows from joins
      polarity_data = entries
                       .where.not(polarity: nil)
                       .reorder(nil)
                       .group(:polarity)
                       .select('polarity, COUNT(DISTINCT entries.id) as count, SUM(DISTINCT entries.total_count) as sum')
                       .map { |row| [row.polarity, { count: row.count, sum: row.sum }] }
                       .to_h

      # Extract counts and sums from the combined data
      entries_polarity_counts = polarity_data.transform_values { |v| v[:count] }
      entries_polarity_sums = polarity_data.transform_values { |v| v[:sum] }

      {
        entries_count: entries_count,
        entries_total_sum: entries_total_sum,
        entries_polarity_counts: entries_polarity_counts,
        entries_polarity_sums: entries_polarity_sums,
        total_entries: entries_count,
        total_interactions: entries_total_sum
      }
    end

    def calculate_site_data(entries)
      # Cache site queries for better performance
      # Use reorder(nil) to remove ORDER BY before GROUP BY
      # Use distinct to avoid counting duplicate rows from joins
      site_counts = Rails.cache.fetch("topic_#{@topic.id}_site_counts_#{Date.current}", expires_in: CACHE_EXPIRATION) do
        entries.distinct.reorder(nil).group('sites.name').count
      end
      
      site_sums = Rails.cache.fetch("topic_#{@topic.id}_site_sums_#{Date.current}", expires_in: CACHE_EXPIRATION) do
        entries.distinct.reorder(nil).group('sites.name').sum(:total_count)
      end

      {
        site_counts: site_counts,
        site_sums: site_sums
      }
    end

    def load_chart_data
      # Use pre-aggregated daily stats for performance - single query
      topic_stats = @topic.topic_stat_dailies.normal_range.order(:topic_date).to_a

      # Build all chart data in one pass
      chart_data = build_chart_data_from_stats(topic_stats)
      
      # Load title stats - single query
      title_stats = @topic.title_topic_stat_dailies.normal_range.order(:topic_date)
      
      chart_data.merge(
        title_chart_entries_counts: title_stats.pluck(:topic_date, :entry_quantity).to_h,
        title_chart_entries_sums: title_stats.pluck(:topic_date, :entry_interaction).to_h
      )
    end

    def build_chart_data_from_stats(stats)
      chart_entries_counts = {}
      chart_entries_sums = {}
      sentiments_counts = {}
      sentiments_sums = {}

      # Single iteration through stats
      stats.each do |stat|
        date = stat.topic_date
        
        # Basic counts
        chart_entries_counts[date] = stat.entry_count
        chart_entries_sums[date] = stat.total_count
        
        # Sentiment counts (using array keys for chartkick)
        sentiments_counts[['positive', date]] = stat.positive_quantity || 0
        sentiments_counts[['neutral', date]] = stat.neutral_quantity || 0
        sentiments_counts[['negative', date]] = stat.negative_quantity || 0
        
        # Sentiment interactions
        sentiments_sums[['positive', date]] = stat.positive_interaction || 0
        sentiments_sums[['neutral', date]] = stat.neutral_interaction || 0
        sentiments_sums[['negative', date]] = stat.negative_interaction || 0
      end

      {
        chart_entries_counts: chart_entries_counts,
        chart_entries_sums: chart_entries_sums,
        chart_entries_sentiments_counts: sentiments_counts,
        chart_entries_sentiments_sums: sentiments_sums
      }
    end

    def calculate_percentages
      # Use memoized topic_data instead of reloading
      entries = topic_data[:entries]
      entries_count = topic_data[:entries_count]
      entries_total_sum = topic_data[:entries_total_sum]
      entries_polarity_counts = topic_data[:entries_polarity_counts]

      # Calculate all entries stats
      all_entries = @topic.all_list_entries
      all_entries_size = all_entries.size
      all_entries_interactions = all_entries.sum(:total_count)

      neutrals = entries_polarity_counts['neutral'] || 0
      positives = entries_polarity_counts['positive'] || 0
      negatives = entries_polarity_counts['negative'] || 0

      percentages = calculate_polarity_percentages(entries_count, positives, negatives, neutrals)
      percentages.merge(calculate_share_of_voice(entries_count, entries_total_sum, all_entries_size, all_entries_interactions))
      percentages.merge(
        promedio: safe_division(entries_total_sum, entries_count),
        most_interactions: entries.order(total_count: :desc).limit(20),
        neutrals: neutrals,
        positives: positives,
        negatives: negatives,
        all_entries_size: all_entries_size,
        all_entries_interactions: all_entries_interactions
      )
    end

    def calculate_polarity_percentages(entries_count, positives, negatives, neutrals)
      return {} if entries_count.zero?

      {
        percentage_positives: safe_percentage(positives, entries_count),
        percentage_negatives: safe_percentage(negatives, entries_count),
        percentage_neutrals: safe_percentage(neutrals, entries_count)
      }
    end

    def calculate_share_of_voice(entries_count, entries_total_sum, all_entries_size, all_entries_interactions)
      total_count = entries_count + all_entries_size
      total_interactions = entries_total_sum + all_entries_interactions

      {
        topic_percentage: safe_percentage(entries_count, total_count),
        all_percentage: safe_percentage(all_entries_size, total_count),
        topic_interactions_percentage: safe_percentage(entries_total_sum, total_interactions, decimals: 1),
        all_interactions_percentage: safe_percentage(all_entries_interactions, total_interactions, decimals: 1)
      }
    end

    def load_tags_and_word_data
      # Use memoized entries
      entries = topic_data[:entries]

      # Cache expensive text analysis
      word_data = load_text_analysis(entries)
      tag_data = load_tag_analysis(entries)
      
      word_data.merge(tag_data).merge(
        report: @topic.reports.last,
        comments: [],
        comments_word_occurrences: []
      )
    end

    def load_text_analysis(entries)
      {
        word_occurrences: Rails.cache.fetch("topic_#{@topic.id}_words_#{Date.current}", expires_in: CACHE_EXPIRATION) do
          entries.word_occurrences
        end,
        bigram_occurrences: Rails.cache.fetch("topic_#{@topic.id}_bigrams_#{Date.current}", expires_in: CACHE_EXPIRATION) do
          entries.bigram_occurrences
        end,
        positive_words: parse_word_list(@topic.positive_words),
        negative_words: parse_word_list(@topic.negative_words)
      }
    end

    def load_tag_analysis(entries)
      # Optimized tag query with single join
      # Use distinct to avoid duplicate counts from entry_topics join
      tags = Tag.joins(:taggings)
                .where(taggings: {
                         taggable_type: Entry.base_class.name,
                         context: 'tags',
                         taggable_id: entries.distinct.select(:id)
                       })
                .group('tags.id', 'tags.name')
                .order(Arel.sql('COUNT(DISTINCT taggings.taggable_id) DESC'))
                .limit(20)
                .select('tags.id, tags.name, COUNT(DISTINCT taggings.taggable_id) AS count')

      # Batch tag interactions query
      tags_interactions = Entry.joins(:tags)
                               .where(id: entries.distinct.select(:id), tags: { id: tags.map(&:id) })
                               .group('tags.name')
                               .sum(:total_count)

      tags_count = tags.each_with_object({}) { |tag, hash| hash[tag.name] = tag.count }

      # Convert site_counts (by name) to site_top_counts (by id) for view compatibility
      # View expects { site_id => count } format
      site_name_counts = topic_data[:site_counts].sort_by { |_, count| -count }.first(12).to_h
      site_id_map = Site.where(name: site_name_counts.keys).pluck(:name, :id).to_h
      site_top_counts = site_name_counts.transform_keys { |name| site_id_map[name] }.compact

      {
        tags: tags,
        tags_interactions: tags_interactions,
        tags_count: tags_count,
        site_top_counts: site_top_counts
      }
    end

    def load_temporal_intelligence
      {
        temporal_summary: safe_call { @topic.temporal_intelligence_summary },
        optimal_time: safe_call { @topic.optimal_publishing_time },
        trend_velocity: safe_call { @topic.trend_velocity } || default_velocity,
        engagement_velocity: safe_call { @topic.engagement_velocity } || default_velocity,
        content_half_life: safe_call { @topic.content_half_life },
        peak_hours: safe_call { @topic.peak_publishing_times_by_hour } || {},
        peak_days: safe_call { @topic.peak_publishing_times_by_day } || {},
        heatmap_data: safe_call { @topic.engagement_heatmap_data } || []
      }
    end

    # Helper methods

    def parse_word_list(word_string)
      word_string.present? ? word_string.split(',').map(&:strip) : []
    end

    def safe_percentage(numerator, denominator, decimals: 0)
      return 0 if denominator.zero?
      (numerator.to_f / denominator * 100).round(decimals)
    end

    def safe_division(numerator, denominator)
      denominator.zero? ? 0 : numerator / denominator
    end

    def safe_call
      yield
    rescue StandardError => e
      Rails.logger.error "Error in DigitalDashboardServices: #{e.class} - #{e.message}"
      Rails.logger.error e.backtrace.first(5).join("\n")
      nil
    end

    def default_velocity
      { velocity_percent: 0, direction: 'stable' }
    end

    def empty_topic_data
      {
        tag_list: [],
        entries: Entry.none,
        entries_count: 0,
        entries_total_sum: 0,
        entries_polarity_counts: {},
        entries_polarity_sums: {},
        site_counts: {},
        site_sums: {},
        total_entries: 0,
        total_interactions: 0
      }
    end
  end
end

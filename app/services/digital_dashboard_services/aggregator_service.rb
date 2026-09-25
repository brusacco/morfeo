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
    CACHE_EXPIRATION = 30.minutes
    CACHE_NAMESPACE = 'digital_dashboard:v3'

    def initialize(topic:, days_range: DAYS_RANGE)
      @topic = topic
      @days_range = (days_range || DAYS_RANGE || 7).to_i # Default to 7 days if not provided
      @start_date = @days_range.days.ago.beginning_of_day
      @end_date = Time.current
      @tags_data = @topic.tags.pluck(:id, :name)
      @tag_ids = @tags_data.map(&:first)
      @tag_names = @tags_data.map(&:last)
      @topic_data_cache = nil # Memoization
    end

    def call
      fetch_cached_with_race_protection(cache_key, expires_in: CACHE_EXPIRATION) do
        {
          topic_data: topic_data,
          chart_data: load_chart_data,
          percentages: calculate_percentages,
          tags_and_words: load_tags_and_word_data,
          temporal_intelligence: load_temporal_intelligence,
          viral_content: detect_viral_content
        }
      end
    end

    private

    def cache_key
      topic_cache_key('payload')
    end

    def site_data_cache_key
      topic_cache_key('site_data')
    end

    def text_analysis_cache_key
      topic_cache_key('text_analysis')
    end

    def topic_cache_key(resource)
      "#{CACHE_NAMESPACE}:topic:#{@topic.id}:#{resource}:#{cache_date_range}"
    end

    def global_digital_stats_cache_key(date_range)
      "#{CACHE_NAMESPACE}:global_stats:#{cache_date_range(date_range[:gte], date_range[:lte])}"
    end

    def cache_date_range(start_date = @start_date, end_date = @end_date)
      "#{start_date.to_date.iso8601}:#{end_date.to_date.iso8601}"
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
      # Topic#list_entries uses EXISTS, so aggregate all entry metrics in one query.
      # Topic#list_entries uses EXISTS, so it returns each entry at most once.
      neutral_value = Entry.polarities.fetch('neutral')
      positive_value = Entry.polarities.fetch('positive')
      negative_value = Entry.polarities.fetch('negative')

      row =
        entries.reorder(nil).pick(
          Arel.sql('COUNT(entries.id)'),
          Arel.sql('COALESCE(SUM(entries.total_count), 0)'),
          Arel.sql("COALESCE(SUM(CASE WHEN entries.polarity = #{neutral_value} THEN 1 ELSE 0 END), 0)"),
          Arel.sql(
            "COALESCE(SUM(CASE WHEN entries.polarity = #{neutral_value} " \
            'THEN entries.total_count ELSE 0 END), 0)'
          ),
          Arel.sql("COALESCE(SUM(CASE WHEN entries.polarity = #{positive_value} THEN 1 ELSE 0 END), 0)"),
          Arel.sql(
            "COALESCE(SUM(CASE WHEN entries.polarity = #{positive_value} " \
            'THEN entries.total_count ELSE 0 END), 0)'
          ),
          Arel.sql("COALESCE(SUM(CASE WHEN entries.polarity = #{negative_value} THEN 1 ELSE 0 END), 0)"),
          Arel.sql(
            "COALESCE(SUM(CASE WHEN entries.polarity = #{negative_value} " \
            'THEN entries.total_count ELSE 0 END), 0)'
          )
        )
      row ||= Array.new(8, 0)

      entries_count, entries_total_sum,
        neutral_count, neutral_sum,
        positive_count, positive_sum,
        negative_count, negative_sum = row

      entries_polarity_counts = {
        'neutral' => neutral_count,
        'positive' => positive_count,
        'negative' => negative_count
      }.reject { |_polarity, count| count.zero? }
      entries_polarity_sums = {
        'neutral' => neutral_sum,
        'positive' => positive_sum,
        'negative' => negative_sum
      }.select { |polarity, _sum| entries_polarity_counts.key?(polarity) }

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
      site_rows =
        fetch_cached_with_race_protection(site_data_cache_key, expires_in: CACHE_EXPIRATION) do
          entries.reorder(nil)
                 .group('sites.id', 'sites.name')
                 .pluck(
                   Arel.sql('sites.name'),
                   Arel.sql('COUNT(entries.id)'),
                   Arel.sql('COALESCE(SUM(entries.total_count), 0)')
                 )
        end

      site_counts = Hash.new(0)
      site_sums = Hash.new(0)
      site_rows.each do |site_name, count, interactions|
        site_counts[site_name] += count
        site_sums[site_name] += interactions
      end

      {
        site_counts: site_counts,
        site_sums: site_sums
      }
    end

    def load_chart_data
      # Use pre-aggregated daily stats for performance - single query
      topic_stats = @topic.topic_stat_dailies
                          .where(topic_date: @start_date.to_date..@end_date.to_date)
                          .order(:topic_date).to_a

      # Build all chart data in one pass
      chart_data = build_chart_data_from_stats(topic_stats)

      # Load title stats - single query
      title_stats = @topic.title_topic_stat_dailies
                          .where(topic_date: @start_date.to_date..@end_date.to_date)
                          .order(:topic_date)

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

      all_entries_size, all_entries_interactions =
        if ENV['USE_DIRECT_ENTRY_TOPICS'] == 'true'
          global_stats = global_digital_stats
          [global_stats[:entries_count], global_stats[:interactions]]
        else
          all_entries = @topic.all_list_entries
          [all_entries.size, all_entries.sum(:total_count)]
        end

      neutrals = entries_polarity_counts['neutral'] || 0
      positives = entries_polarity_counts['positive'] || 0
      negatives = entries_polarity_counts['negative'] || 0

      percentages = calculate_polarity_percentages(entries_count, positives, negatives, neutrals)
      percentages
        .merge(
          calculate_share_of_voice(
            entries_count,
            entries_total_sum,
            all_entries_size,
            all_entries_interactions
          )
        )
        .merge(
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

    def global_digital_stats
      date_range = @topic.default_date_range
      cache_key = global_digital_stats_cache_key(date_range)

      fetch_cached_with_race_protection(cache_key, expires_in: CACHE_EXPIRATION) do
        entries_count, interactions = Entry.enabled
                                           .where(published_at: date_range[:gte]..date_range[:lte])
                                           .joins(:site)
                                           .reorder(nil)
                                           .pick(
                                             Arel.sql('COUNT(entries.id)'),
                                             Arel.sql('COALESCE(SUM(entries.total_count), 0)')
                                           )

        { entries_count: entries_count, interactions: interactions }
      end
    end

    def load_tags_and_word_data
      # Use memoized entries
      entries = topic_data[:entries]

      # Cache expensive text analysis
      word_data = load_text_analysis(entries)
      tag_data = load_tag_analysis(entries)

      word_data.merge(tag_data).merge(report: @topic.reports.last, comments: [], comments_word_occurrences: [])
    end

    def load_text_analysis(entries)
      text_data =
        fetch_cached_with_race_protection(
          text_analysis_cache_key,
          expires_in: CACHE_EXPIRATION
        ) do
          entries.text_occurrences(word_limit: 100, bigram_limit: 100)
        end

      {
        word_occurrences: text_data[:word_occurrences],
        bigram_occurrences: text_data[:bigram_occurrences],
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

      # Convert site_counts to include site objects for avatar display
      site_name_counts = topic_data[:site_counts].sort_by { |_, count| -count }
                                                 .first(12)
      site_name_interactions = topic_data[:site_sums].sort_by { |_, sum| -sum }
                                                     .first(12)

      # Load Site objects with their data
      site_names = (site_name_counts.map(&:first) + site_name_interactions.map(&:first)).uniq
      sites_by_name = Site.where(name: site_names).index_by(&:name)

      # Build arrays with site objects
      site_top_counts =
        site_name_counts.map do |site_name, count|
          { site: sites_by_name[site_name], name: site_name, count: count }
        end

      site_top_interactions =
        site_name_interactions.map do |site_name, interactions|
          { site: sites_by_name[site_name], name: site_name, interactions: interactions }
        end

      {
        tags: tags,
        tags_interactions: tags_interactions,
        tags_count: tags_count,
        site_top_counts: site_top_counts,
        site_top_interactions: site_top_interactions
      }
    end

    def load_temporal_intelligence
      optimal_time = safe_call { @topic.optimal_publishing_time }
      trend_velocity = safe_call { @topic.trend_velocity } || default_velocity
      engagement_velocity = safe_call { @topic.engagement_velocity } || default_velocity
      content_half_life = safe_call { @topic.content_half_life }
      peak_hours = safe_call { @topic.peak_publishing_times_by_hour } || {}
      peak_days = safe_call { @topic.peak_publishing_times_by_day } || {}
      summary_peak_hours = peak_hours.sort_by { |_, value| -value[:avg_engagement] }
                                     .first(3)
      summary_peak_days = peak_days.sort_by { |_, value| -value[:avg_engagement] }
                                   .first(3)

      {
        temporal_summary: {
          optimal_time: optimal_time,
          trend_velocity: trend_velocity,
          engagement_velocity: engagement_velocity,
          content_half_life: content_half_life,
          peak_hours: summary_peak_hours,
          peak_days: summary_peak_days
        },
        optimal_time: optimal_time,
        trend_velocity: trend_velocity,
        engagement_velocity: engagement_velocity,
        content_half_life: content_half_life,
        peak_hours: peak_hours,
        peak_days: peak_days,
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

    # ========================================
    # VIRAL CONTENT DETECTION
    # ========================================
    def detect_viral_content
      return [] if @tag_names.empty?

      # Get entries from last 24 hours
      recent_entries = Entry.enabled
                            .where(published_at: 24.hours.ago..Time.current)
                            .with_any_tag_ids(@tag_ids, context: :tags)
                            .includes(:site)

      # Use .to_a.size instead of .count to avoid SQL issues with acts_as_taggable_on
      entries_array = recent_entries.to_a
      return [] if entries_array.empty?

      # Simple approach: Any entry with > 100 interactions in last 6h is considered viral
      # This is more practical than statistical analysis for short time windows
      viral_threshold = 100

      # Get viral entries
      viral_entries = entries_array.select { |e| e.total_count > viral_threshold }
                                   .sort_by { |e| -e.total_count }
                                   .take(10)

      return [] if viral_entries.empty?

      # Calculate baseline for comparison (median of non-zero values, or 1 if none)
      engagement_values = entries_array.map(&:total_count)
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

      viral_entries.map do |entry|
        {
          entry: entry,
          multiplier: (entry.total_count / baseline).round(1),
          engagement: entry.total_count,
          published_at: entry.published_at,
          baseline: baseline.round(0) # For transparency
        }
      end
    end

    # Calculate median from sorted array
    # More robust than mean for viral detection
    def calculate_median(sorted_values)
      return 0 if sorted_values.empty?

      size = sorted_values.size
      if size.odd?
        sorted_values[size / 2].to_f
      else
        (sorted_values[(size / 2) - 1] + sorted_values[size / 2]) / 2.0
      end
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

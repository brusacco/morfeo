# frozen_string_literal: true

module DigitalDashboardServices
  class AggregatorService < ApplicationService
    def initialize(topic:, days_range: DAYS_RANGE)
      @topic = topic
      @days_range = days_range
      @start_date = days_range.days.ago.beginning_of_day
      @end_date = Time.current
    end

    def call
      Rails.cache.fetch(cache_key, expires_in: 1.hour) do
        {
          topic_data: load_topic_data,
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

    def load_topic_data
      tag_list = @topic.tags.map(&:name)
      entries = @topic.list_entries

      # Precompute aggregates to avoid multiple SQL queries
      entries_count = entries.size
      entries_total_sum = entries.sum(:total_count)

      # Combine polarity aggregations into a single query
      entries_polarity_data = entries
                                .where.not(polarity: nil)
                                .group(:polarity)
                                .pluck(
                                  :polarity,
                                  Arel.sql('COUNT(*)'),
                                  Arel.sql('SUM(entries.total_count)')
                                )
                                .map { |p, c, s| [p, { count: c, sum: s }] }
                                .to_h

      # Extract counts and sums from the combined data
      entries_polarity_counts = entries_polarity_data.transform_values { |v| v[:count] }
      entries_polarity_sums = entries_polarity_data.transform_values { |v| v[:sum] }

      # Precompute site group queries to avoid duplicate group-by operations
      site_counts = Rails.cache.fetch("topic_#{@topic.id}_site_counts", expires_in: 1.hour) do
        entries.group('sites.name').count('*')
      end
      
      site_sums = Rails.cache.fetch("topic_#{@topic.id}_site_sums", expires_in: 1.hour) do
        entries.group('sites.name').sum(:total_count)
      end

      {
        tag_list: tag_list,
        entries: entries,
        entries_count: entries_count,
        entries_total_sum: entries_total_sum,
        entries_polarity_counts: entries_polarity_counts,
        entries_polarity_sums: entries_polarity_sums,
        site_counts: site_counts,
        site_sums: site_sums,
        total_entries: entries_count,
        total_interactions: entries_total_sum
      }
    end

    def load_chart_data
      # Use pre-aggregated daily stats for performance
      topic_stats = @topic.topic_stat_dailies.normal_range.order(:topic_date)

      # Build chart data from aggregated stats
      chart_entries_counts = topic_stats.pluck(:topic_date, :entry_count).to_h
      chart_entries_sums = topic_stats.pluck(:topic_date, :total_count).to_h

      # Sentiment chart data from aggregated stats
      chart_entries_sentiments_counts = {}
      chart_entries_sentiments_sums = {}

      topic_stats.each do |stat|
        date = stat.topic_date
        # Counts by sentiment
        chart_entries_sentiments_counts[['positive', date]] = stat.positive_quantity || 0
        chart_entries_sentiments_counts[['neutral', date]] = stat.neutral_quantity || 0
        chart_entries_sentiments_counts[['negative', date]] = stat.negative_quantity || 0

        # Interactions by sentiment
        chart_entries_sentiments_sums[['positive', date]] = stat.positive_interaction || 0
        chart_entries_sentiments_sums[['neutral', date]] = stat.neutral_interaction || 0
        chart_entries_sentiments_sums[['negative', date]] = stat.negative_interaction || 0
      end

      # Use pre-aggregated title stats for performance
      title_stats = @topic.title_topic_stat_dailies.normal_range.order(:topic_date)

      title_chart_entries_counts = title_stats.pluck(:topic_date, :entry_quantity).to_h
      title_chart_entries_sums = title_stats.pluck(:topic_date, :entry_interaction).to_h

      {
        chart_entries_counts: chart_entries_counts,
        chart_entries_sums: chart_entries_sums,
        chart_entries_sentiments_counts: chart_entries_sentiments_counts,
        chart_entries_sentiments_sums: chart_entries_sentiments_sums,
        title_chart_entries_counts: title_chart_entries_counts,
        title_chart_entries_sums: title_chart_entries_sums
      }
    end

    def calculate_percentages
      topic_data = load_topic_data
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

      percentages = {}

      if entries_count > 0
        percentages[:percentage_positives] = (Float(positives) / entries_count * 100).round(0)
        percentages[:percentage_negatives] = (Float(negatives) / entries_count * 100).round(0)
        percentages[:percentage_neutrals] = (Float(neutrals) / entries_count * 100).round(0)

        total_count = entries_count + all_entries_size
        if total_count > 0
          percentages[:topic_percentage] = (Float(entries_count) / total_count * 100).round(0)
          percentages[:all_percentage] = (Float(all_entries_size) / total_count * 100).round(0)
        end

        total_interactions = entries_total_sum + all_entries_interactions
        if total_interactions > 0
          percentages[:topic_interactions_percentage] = (Float(entries_total_sum) / total_interactions * 100).round(1)
          percentages[:all_interactions_percentage] = (Float(all_entries_interactions) / total_interactions * 100).round(1)
        end
      end

      percentages[:promedio] = entries_count.zero? ? 0 : entries_total_sum / entries_count
      percentages[:most_interactions] = entries.order(total_count: :desc).limit(20)
      percentages[:neutrals] = neutrals
      percentages[:positives] = positives
      percentages[:negatives] = negatives
      percentages[:all_entries_size] = all_entries_size
      percentages[:all_entries_interactions] = all_entries_interactions

      percentages
    end

    def load_tags_and_word_data
      entries = @topic.list_entries

      # Word occurrences and bigrams
      word_occurrences = Rails.cache.fetch("topic_#{@topic.id}_word_occurrences", expires_in: 1.hour) do
        entries.word_occurrences
      end
      
      bigram_occurrences = Rails.cache.fetch("topic_#{@topic.id}_bigram_occurrences", expires_in: 1.hour) do
        entries.bigram_occurrences
      end

      report = @topic.reports.last

      # Comments data (empty for now, comments feature disabled)
      comments = []
      comments_word_occurrences = []

      # Sentiment words
      positive_words = @topic.positive_words.split(',') if @topic.positive_words.present?
      negative_words = @topic.negative_words.split(',') if @topic.negative_words.present?

      # Tags analysis
      tags = Tag.joins(:taggings)
                .where(taggings: {
                         taggable_type: Entry.base_class.name,
                         context: 'tags',
                         taggable_id: entries.select(:id)
                       })
                .group('tags.id', 'tags.name')
                .order(Arel.sql('COUNT(DISTINCT taggings.taggable_id) DESC'))
                .limit(20)
                .select('tags.id, tags.name, COUNT(DISTINCT taggings.taggable_id) AS count')

      tags_interactions = Entry.joins(:tags)
                               .where(id: entries.select(:id), tags: { id: tags.map(&:id) })
                               .group('tags.name')
                               .sum(:total_count)

      tags_count = {}
      tags.each { |n| tags_count[n.name] = n.count }

      # Top sites
      site_top_counts = entries.group('site_id').order(Arel.sql('COUNT(*) DESC')).limit(12).count

      {
        word_occurrences: word_occurrences,
        bigram_occurrences: bigram_occurrences,
        report: report,
        comments: comments,
        comments_word_occurrences: comments_word_occurrences,
        positive_words: positive_words,
        negative_words: negative_words,
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
        trend_velocity: safe_call { @topic.trend_velocity } || { velocity_percent: 0, direction: 'stable' },
        engagement_velocity: safe_call { @topic.engagement_velocity } || { velocity_percent: 0, direction: 'stable' },
        content_half_life: safe_call { @topic.content_half_life },
        peak_hours: safe_call { @topic.peak_publishing_times_by_hour } || {},
        peak_days: safe_call { @topic.peak_publishing_times_by_day } || {},
        heatmap_data: safe_call { @topic.engagement_heatmap_data } || []
      }
    end

    def safe_call
      yield
    rescue StandardError => e
      Rails.logger.error "Error in safe_call: #{e.message}"
      nil
    end
  end
end


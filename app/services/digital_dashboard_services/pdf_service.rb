# frozen_string_literal: true

module DigitalDashboardServices
  # Service for generating PDF-specific data for digital topic dashboards
  # Handles special calculations and data formatting required for PDF reports
  #
  # @example
  #   pdf_data = DigitalDashboardServices::PdfService.call(topic: @topic)
  #   pdf_data[:topic_data]     # => Topic entries and statistics
  #   pdf_data[:chart_data]     # => Chart data for visualizations
  #   pdf_data[:tags_and_words] # => Tags and word analysis
  #   pdf_data[:percentages]    # => Share of voice percentages
  class PdfService < ApplicationService
    # Spanish stop words for text analysis (extracted to constant for reusability)
    STOP_WORDS = %w[
      el la los las de del un una unos unas en y a es por para con que su al lo si se le
      como más pero sus me ya o fue todo hay muy era estar han este sido este sobre hacer
      cuando dos estado otra también ser tiene él hasta bien puede hace entre sin va fueron
      desde están mi porque ellos donde yo hay uno hay qué siendo son hace cual sea
      hace han tres alguna puede poco esto estos antes muchos tal otras pues eso poco hace
      les sino vez sólo han menos ahora tan mayor uno cada tras dentro dice decir este tenía
      cinco entonces casi mejor debe ello fin hacia dijo medio misma además toda aún bajo hizo
      acá tú aquí mí ti yo le dió les dio ex aún hoy eran será aquí tal nada manera están donde hacer
    ].freeze

    # Polarity mapping for normalization
    POLARITY_MAP = {
      0 => 'neutral', '0' => 'neutral', 'neutral' => 'neutral', :neutral => 'neutral',
      1 => 'positive', '1' => 'positive', 'positive' => 'positive', :positive => 'positive',
      2 => 'negative', '2' => 'negative', 'negative' => 'negative', :negative => 'negative'
    }.freeze

    # Minimum word/bigram length for analysis
    MIN_WORD_LENGTH = 3
    # Minimum frequency thresholds
    MIN_WORD_FREQUENCY = 5
    MIN_BIGRAM_FREQUENCY = 2

    def initialize(topic:)
      @topic = topic
      @start_date = DAYS_RANGE.days.ago.beginning_of_day
      @end_date = Time.zone.now.end_of_day
      @tag_names = @topic.tags.pluck(:name) # Cache tag names
      @topic_data_cache = nil # Memoization for topic_data
    end

    def call
      {
        topic_data: topic_data,
        chart_data: load_chart_data,
        tags_and_words: load_tags_and_words,
        percentages: calculate_pdf_percentages
      }
    end

    private

    # Memoized topic data to avoid reloading entries multiple times
    def topic_data
      @topic_data_cache ||= load_topic_data
    end

    def load_topic_data
      return empty_topic_data if @tag_names.empty?

      # Use direct association (optimized with entry_topics)
      # This matches the aggregator service pattern for consistency
      base_entries = @topic.report_entries(@start_date, @end_date)
                          .includes(:tags, :site)

      # Execute aggregations with DISTINCT to avoid duplicate counts
      entries_count = base_entries.distinct.count
      entries_total_sum = base_entries.distinct.sum(:total_count)
      
      # Batch polarity queries
      polarity_data = calculate_polarity_data(base_entries)
      
      # Batch site queries
      site_data = calculate_site_data(base_entries)

      {
        tag_list: @tag_names,
        entries: base_entries.order(published_at: :desc),
        entries_count: entries_count,
        entries_total_sum: entries_total_sum,
        **polarity_data,
        **site_data,
        total_entries: entries_count,
        total_interactions: entries_total_sum
      }
    end

    def calculate_polarity_data(entries)
      # Use distinct to avoid counting duplicate rows from joins
      base_query = entries.distinct.reorder(nil)
      
      polarity_counts_raw = base_query.group(:polarity).count
      polarity_sums_raw = base_query.group(:polarity).sum(:total_count)

      {
        entries_polarity_counts: normalize_polarity_hash(polarity_counts_raw),
        entries_polarity_sums: normalize_polarity_hash(polarity_sums_raw)
      }
    end

    def calculate_site_data(entries)
      # Use distinct to avoid counting duplicate rows from joins
      base_query = entries.distinct.reorder(nil).group('sites.name')
      
      site_counts = base_query.count
      site_sums = base_query.sum(:total_count)
      site_top_counts = site_counts.sort_by { |_, count| -count }.first(10).to_h

      # Build site_id mapping efficiently
      site_names = site_counts.keys
      site_id_map = Site.where(name: site_names).pluck(:name, :id).to_h
      entries_by_site_id = site_counts.transform_keys { |name| site_id_map[name] }.compact

      {
        site_counts: site_counts,
        site_sums: site_sums,
        site_top_counts: site_top_counts,
        entries_by_site_count: site_counts,
        entries_by_site_sum: site_sums,
        entries_by_site_id: entries_by_site_id
      }
    end

    def load_chart_data
      # Load pre-aggregated stats (single query)
      stats = @topic.topic_stat_dailies.normal_range.order(:topic_date).to_a

      # Build all chart data structures in one pass
      chart_data = build_chart_data_from_stats(stats)
      
      # Load title stats (single query)
      title_stats = @topic.title_topic_stat_dailies.normal_range.order(:topic_date)
      title_data = {
        title_chart_entries_counts: title_stats.pluck(:topic_date, :entry_quantity).to_h,
        title_chart_entries_sums: title_stats.pluck(:topic_date, :entry_interaction).to_h
      }

      # Merge and create PDF-specific data
      chart_data.merge(title_data).tap do |data|
        data[:title_chart_entries_count_data] = data[:title_chart_entries_counts]
        data[:title_chart_entries_sum_data] = data[:title_chart_entries_sums]
        data[:chart_entries_sentiments_count_data] = data[:chart_entries_sentiments_counts]
        data[:chart_entries_sentiments_sum_data] = data[:chart_entries_sentiments_sums]
      end
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

    def load_tags_and_words
      entries = topic_data[:entries].to_a # Force load once

      # Parallel text analysis
      word_data = analyze_text(entries)
      tag_data = analyze_tags(entries)

      word_data.merge(tag_data).merge(
        report: @topic.reports.last,
        comments: nil,
        comments_word_occurrences: {}
      )
    end

    def analyze_text(entries)
      # Analyze words and bigrams in one pass through entries
      words_hash = {}
      bigrams_hash = {}

      entries.each do |entry|
        next unless entry.title.present?

        text = build_entry_text(entry)
        normalized_words = tokenize_text(text)
        
        # Count words
        normalized_words.each { |word| words_hash[word] = (words_hash[word] || 0) + 1 }
        
        # Count bigrams
        normalized_words.each_cons(2) do |w1, w2|
          bigram = "#{w1} #{w2}"
          bigrams_hash[bigram] = (bigrams_hash[bigram] || 0) + 1
        end
      end

      # Filter and sort
      {
        word_occurrences: filter_and_sort_occurrences(words_hash, MIN_WORD_FREQUENCY, 50),
        bigram_occurrences: filter_and_sort_occurrences(bigrams_hash, MIN_BIGRAM_FREQUENCY, 30)
      }
    end

    def analyze_tags(entries)
      tags = @topic.tags.to_a
      return empty_tag_data if tags.empty?

      # Pre-load entries by tag in single pass
      # Use .map(&:name) instead of .pluck(:name) to use preloaded associations
      entries_by_tag = entries.group_by { |entry| (entry.tags.map(&:name) & @tag_names).first }.compact

      tags_interactions = {}
      tags_count = {}

      tags.each do |tag|
        tag_entries = entries_by_tag[tag.name] || []
        tags_count[tag.name] = tag_entries.size
        tags_interactions[tag.name] = tag_entries.sum(&:total_count)
        tag.interactions = tags_interactions[tag.name]
      end

      {
        tags: tags,
        tags_interactions: tags_interactions,
        tags_count: tags_count,
        positive_words: parse_word_list(@topic.positive_words),
        negative_words: parse_word_list(@topic.negative_words)
      }
    end

    def calculate_pdf_percentages
      entries_count = topic_data[:entries_count]
      entries_total_sum = topic_data[:entries_total_sum]

      return empty_percentages if entries_count.zero?

      # Calculate share of voice (excluding topic entries)
      sov_data = calculate_share_of_voice(entries_count, entries_total_sum)
      
      # Calculate polarity percentages
      polarity_percentages = calculate_polarity_percentages(topic_data[:entries_polarity_counts], entries_count)
      
      # Get top entries and polarity stats
      top_entries_data = calculate_top_entries_data
      polarity_stats = calculate_polarity_stats(topic_data[:entries_polarity_sums])

      # Calculate average
      promedio = (entries_total_sum.to_f / entries_count).round(0)

      polarity_percentages.merge(sov_data).merge(top_entries_data).merge(polarity_stats).merge(
        promedio: promedio
      )
    end

    def calculate_share_of_voice(entries_count, entries_total_sum)
      # Efficient query: count/sum in single query with exclusion
      topic_entry_ids = topic_data[:entries].pluck(:id)
      other_entries = Entry.enabled.normal_range.where.not(id: topic_entry_ids)
      
      all_entries_size = other_entries.count
      all_entries_interactions = other_entries.sum(:total_count)

      # Calculate percentages with safe division
      total_count = entries_count + all_entries_size
      total_interactions = entries_total_sum + all_entries_interactions

      {
        all_entries_size: all_entries_size,
        all_entries_interactions: all_entries_interactions,
        topic_percentage: safe_percentage(entries_count, total_count),
        all_percentage: safe_percentage(all_entries_size, total_count),
        topic_interactions_percentage: safe_percentage(entries_total_sum, total_interactions, decimals: 1),
        all_interactions_percentage: safe_percentage(all_entries_interactions, total_interactions, decimals: 1)
      }
    end

    def calculate_polarity_percentages(polarity_counts, total_count)
      {
        percentage_positives: safe_percentage(polarity_counts['positive'] || 0, total_count),
        percentage_negatives: safe_percentage(polarity_counts['negative'] || 0, total_count),
        percentage_neutrals: safe_percentage(polarity_counts['neutral'] || 0, total_count)
      }
    end

    def calculate_top_entries_data
      ordered_entries = topic_data[:entries].order(total_count: :desc)
      
      {
        most_interactions: ordered_entries.limit(10),
        most_interactions_single: ordered_entries.first
      }
    end

    def calculate_polarity_stats(polarity_sums)
      {
        positives: polarity_sums['positive'] || 0,
        negatives: polarity_sums['negative'] || 0,
        neutrals: polarity_sums['neutral'] || 0
      }
    end

    # Helper methods

    def build_entry_text(entry)
      content = entry.content.presence || entry.description.presence || ''
      "#{entry.title} #{content}"
    end

    def tokenize_text(text)
      text.gsub(/[[:punct:]]/, '')
          .split
          .map { |word| word.downcase.strip }
          .select { |word| word.length >= MIN_WORD_LENGTH && !STOP_WORDS.include?(word) }
    end

    def filter_and_sort_occurrences(hash, min_frequency, limit)
      hash.select { |_, count| count > min_frequency }
          .sort_by { |_, count| -count }
          .first(limit)
    end

    def normalize_polarity_hash(hash)
      hash.transform_keys { |key| POLARITY_MAP[key] || key.to_s }
    end

    def parse_word_list(word_string)
      word_string.present? ? word_string.split(',').map(&:strip) : []
    end

    def safe_percentage(numerator, denominator, decimals: 0)
      return 0 if denominator.zero?
      (numerator.to_f / denominator * 100).round(decimals)
    end

    # Empty data structures for edge cases

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
        site_top_counts: {},
        total_entries: 0,
        total_interactions: 0,
        entries_by_site_count: {},
        entries_by_site_sum: {},
        entries_by_site_id: {}
      }
    end

    def empty_tag_data
      {
        tags: [],
        tags_interactions: {},
        tags_count: {},
        positive_words: [],
        negative_words: []
      }
    end

    def empty_percentages
      {
        percentage_positives: 0,
        percentage_negatives: 0,
        percentage_neutrals: 0,
        topic_percentage: 0,
        all_percentage: 0,
        topic_interactions_percentage: 0,
        all_interactions_percentage: 0,
        promedio: 0,
        most_interactions: [],
        most_interactions_single: nil,
        neutrals: 0,
        positives: 0,
        negatives: 0,
        all_entries_size: 0,
        all_entries_interactions: 0
      }
    end
  end
end

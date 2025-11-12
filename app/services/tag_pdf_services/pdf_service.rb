# frozen_string_literal: true

module TagPdfServices
  # Service for generating PDF-specific data for tag dashboards
  # Handles special calculations and data formatting required for PDF reports
  #
  # @example
  #   pdf_data = TagPdfServices::PdfService.call(tag: @tag)
  #   pdf_data[:tag_data]     # => Tag entries and statistics
  #   pdf_data[:chart_data]     # => Chart data for visualizations
  #   pdf_data[:tags_and_words] # => Tags and word analysis
  #   pdf_data[:percentages]    # => Sentiment percentages
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

    def initialize(tag:, days_range: DAYS_RANGE)
      @tag = tag
      @days_range = (days_range || DAYS_RANGE || 7).to_i # Default to 7 days if not provided
      @start_date = @days_range.days.ago.beginning_of_day
      @end_date = Time.zone.now.end_of_day
      @tag_data_cache = nil # Memoization for tag_data
    end

    def call
      {
        tag_data: tag_data,
        chart_data: load_chart_data,
        tags_and_words: load_tags_and_words,
        percentages: calculate_pdf_percentages
      }
    end

    private

    # Memoized tag data to avoid reloading entries multiple times
    def tag_data
      @tag_data_cache ||= load_tag_data
    end

    def load_tag_data
      # Use report_entries method from Tag model
      base_entries = @tag.report_entries(@start_date, @end_date)
                          .includes(:tags, :site)

      # Execute aggregations with DISTINCT to avoid duplicate counts
      entries_count = base_entries.distinct.count
      entries_total_sum = base_entries.distinct.sum(:total_count)
      
      # Batch polarity queries
      polarity_data = calculate_polarity_data(base_entries)
      
      # Batch site queries
      site_data = calculate_site_data(base_entries)

      {
        tag_name: @tag.name,
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
      entries = tag_data[:entries].to_a
      
      # Group by day for chart data
      entries_by_day = entries.group_by { |e| e.published_at.to_date }
      
      chart_entries_counts = {}
      chart_entries_sums = {}
      sentiments_counts = {}
      sentiments_sums = {}

      entries_by_day.each do |date, day_entries|
        chart_entries_counts[date] = day_entries.size
        chart_entries_sums[date] = day_entries.sum(&:total_count)
        
        # Sentiment counts
        day_entries.group_by(&:polarity).each do |polarity, polarity_entries|
          normalized_polarity = POLARITY_MAP[polarity] || polarity.to_s
          sentiments_counts[[normalized_polarity, date]] = polarity_entries.size
          sentiments_sums[[normalized_polarity, date]] = polarity_entries.sum(&:total_count)
        end
      end

      # Title entries data
      title_entries = @tag.report_title_entries(@start_date, @end_date).to_a
      title_entries_by_day = title_entries.group_by { |e| e.published_at.to_date }
      
      title_chart_entries_counts = {}
      title_chart_entries_sums = {}

      title_entries_by_day.each do |date, day_entries|
        title_chart_entries_counts[date] = day_entries.size
        title_chart_entries_sums[date] = day_entries.sum(&:total_count)
      end

      {
        chart_entries_counts: chart_entries_counts,
        chart_entries_sums: chart_entries_sums,
        chart_entries_sentiments_counts: sentiments_counts,
        chart_entries_sentiments_sums: sentiments_sums,
        title_chart_entries_counts: title_chart_entries_counts,
        title_chart_entries_sums: title_chart_entries_sums,
        title_chart_entries_count_data: title_chart_entries_counts,
        title_chart_entries_sum_data: title_chart_entries_sums,
        chart_entries_sentiments_count_data: sentiments_counts,
        chart_entries_sentiments_sum_data: sentiments_sums
      }
    end

    def load_tags_and_words
      entries = tag_data[:entries].to_a # Force load once

      # Parallel text analysis
      word_data = analyze_text(entries)
      tag_data = analyze_tags(entries)

      word_data.merge(tag_data).merge(
        report: nil, # Tags don't have reports like topics
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
      # Get related tags (excluding the current tag)
      related_tags = Entry.joins(:tags)
                          .where(id: entries.map(&:id))
                          .where.not(tags: { id: @tag.id })
                          .group('tags.id', 'tags.name')
                          .order(Arel.sql('COUNT(DISTINCT entries.id) DESC'))
                          .limit(20)
                          .select('tags.id, tags.name, COUNT(DISTINCT entries.id) AS count')

      return empty_tag_analysis_data if related_tags.empty?

      tags_interactions = {}
      tags_count = {}

      related_tags.each do |tag|
        tag_entries = entries.select { |e| e.tags.map(&:id).include?(tag.id) }
        tags_count[tag.name] = tag_entries.size
        tags_interactions[tag.name] = tag_entries.sum(&:total_count)
      end

      {
        tags: related_tags,
        tags_interactions: tags_interactions,
        tags_count: tags_count,
        positive_words: [], # Tags don't have positive/negative words like topics
        negative_words: []
      }
    end

    def calculate_pdf_percentages
      entries_count = tag_data[:entries_count]
      entries_total_sum = tag_data[:entries_total_sum]

      return empty_percentages if entries_count.zero?

      # Calculate polarity percentages
      polarity_percentages = calculate_polarity_percentages(tag_data[:entries_polarity_counts], entries_count)
      
      # Get top entries and polarity stats
      top_entries_data = calculate_top_entries_data
      polarity_stats = calculate_polarity_stats(tag_data[:entries_polarity_sums])

      # Calculate average
      promedio = (entries_total_sum.to_f / entries_count).round(0)

      polarity_percentages.merge(top_entries_data).merge(polarity_stats).merge(
        promedio: promedio
      )
    end

    def calculate_polarity_percentages(polarity_counts, total_count)
      {
        percentage_positives: safe_percentage(polarity_counts['positive'] || 0, total_count),
        percentage_negatives: safe_percentage(polarity_counts['negative'] || 0, total_count),
        percentage_neutrals: safe_percentage(polarity_counts['neutral'] || 0, total_count)
      }
    end

    def calculate_top_entries_data
      ordered_entries = tag_data[:entries].order(total_count: :desc)
      
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

    def safe_percentage(numerator, denominator, decimals: 0)
      return 0 if denominator.zero?
      (numerator.to_f / denominator * 100).round(decimals)
    end

    # Empty data structures for edge cases

    def empty_tag_data
      {
        tag_name: @tag.name,
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

    def empty_tag_analysis_data
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
        promedio: 0,
        most_interactions: [],
        most_interactions_single: nil,
        neutrals: 0,
        positives: 0,
        negatives: 0
      }
    end
  end
end


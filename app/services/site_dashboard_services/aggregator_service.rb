# frozen_string_literal: true

module SiteDashboardServices
  # Service for aggregating site dashboard data
  # Optimized for performance with caching and limiting
  class AggregatorService < ApplicationService
    CACHE_EXPIRATION = 30.minutes
    MAX_ENTRIES_FOR_TEXT_ANALYSIS = 500 # Limit to prevent slow analysis

    def initialize(site:)
      @site = site
    end

    def call
      # Don't cache the entire result (contains ActiveRecord relations)
      # Cache only expensive calculations separately
      {
        entries_stats: load_entries_stats,
        entries: load_entries,
        word_occurrences: load_word_occurrences,
        bigram_occurrences: load_bigram_occurrences,
        tags_data: load_tags_data
      }
    end

    private

    def cache_key
      "site_dashboard_#{@site.id}_#{Date.current}"
    end

    def load_entries_stats
      @site.entries.enabled.normal_range.group_by_day(:published_at)
    end

    def load_entries
      # Load with associations for display, ordered by interactions
      @site.entries
           .includes(:tags)
           .enabled
           .normal_range
           .order(published_at: :desc)
    end

    def load_word_occurrences
      # Use cached result or calculate
      Rails.cache.fetch("site_#{@site.id}_words_#{Date.current}", expires_in: CACHE_EXPIRATION) do
        # Limit entries for text analysis to prevent slowness
        sample_entries = @site.entries
                              .enabled
                              .normal_range
                              .order(total_count: :desc)
                              .limit(MAX_ENTRIES_FOR_TEXT_ANALYSIS)
                              .pluck(:title, :content, :description)
        
        calculate_word_occurrences(sample_entries)
      end
    end

    def load_bigram_occurrences
      # Use cached result or calculate
      Rails.cache.fetch("site_#{@site.id}_bigrams_#{Date.current}", expires_in: CACHE_EXPIRATION) do
        # Limit entries for text analysis to prevent slowness
        sample_entries = @site.entries
                              .enabled
                              .normal_range
                              .order(total_count: :desc)
                              .limit(MAX_ENTRIES_FOR_TEXT_ANALYSIS)
                              .pluck(:title, :content, :description)
        
        calculate_bigram_occurrences(sample_entries)
      end
    end

    def load_tags_data
      entries = load_entries
      
      # Cache the tag data separately (without singleton methods)
      cached_tag_data = Rails.cache.fetch("site_#{@site.id}_tags_#{Date.current}", expires_in: CACHE_EXPIRATION) do
        # Get tags efficiently
        tags_raw = Tag.joins(:taggings)
                      .where(taggings: {
                               taggable_type: 'Entry',
                               context: 'tags',
                               taggable_id: entries.select(:id)
                             })
                      .group('tags.id', 'tags.name')
                      .order(Arel.sql('COUNT(DISTINCT taggings.taggable_id) DESC'))
                      .limit(20)
                      .pluck(Arel.sql('tags.id'), Arel.sql('tags.name'), Arel.sql('COUNT(DISTINCT taggings.taggable_id)'))
                      .map { |id, name, count| { id: id, name: name, count: count } }

        # Calculate tag interactions
        tag_ids = tags_raw.map { |t| t[:id] }
        tags_interactions = if tag_ids.any?
                             Entry.joins(:tags)
                                  .where(id: entries.select(:id), tags: { id: tag_ids })
                                  .group('tags.name')
                                  .sum(:total_count)
                           else
                             {}
                           end

        {
          tags_raw: tags_raw,
          tags_interactions: tags_interactions
        }
      end

      # Reconstruct tag objects with interactions
      tags = cached_tag_data[:tags_raw].map do |tag_data|
        tag = Tag.new(id: tag_data[:id], name: tag_data[:name])
        tag.instance_variable_set(:@count, tag_data[:count])
        tag.define_singleton_method(:count) { @count }
        
        interaction_count = cached_tag_data[:tags_interactions][tag_data[:name]] || 0
        tag.define_singleton_method(:interactions) { interaction_count }
        
        tag
      end

      {
        tags: tags,
        tags_interactions: cached_tag_data[:tags_interactions]
      }
    end

    # Text analysis helpers

    def calculate_word_occurrences(entries_data)
      word_frequency = Hash.new(0)
      stop_words = load_stop_words

      entries_data.each do |title, content, description|
        text = [title, content, description].compact.join(' ')
        words = extract_words(text)
        
        words.each do |word|
          next if stop_words.include?(word.downcase)
          next if word.length < 3
          word_frequency[word.downcase] += 1
        end
      end

      # Return top 50 words, sorted by frequency
      word_frequency.select { |_, count| count > 5 }
                    .sort_by { |_, count| -count }
                    .first(50)
    end

    def calculate_bigram_occurrences(entries_data)
      bigram_frequency = Hash.new(0)
      stop_words = load_stop_words

      entries_data.each do |title, content, description|
        text = [title, content, description].compact.join(' ')
        words = extract_words(text)
        
        # Create bigrams
        words.each_cons(2) do |word1, word2|
          w1 = word1.downcase
          w2 = word2.downcase
          
          next if stop_words.include?(w1) || stop_words.include?(w2)
          next if w1.length < 3 || w2.length < 3
          
          bigram = "#{w1} #{w2}"
          bigram_frequency[bigram] += 1
        end
      end

      # Return top 50 bigrams, sorted by frequency
      bigram_frequency.select { |_, count| count > 2 }
                      .sort_by { |_, count| -count }
                      .first(50)
    end

    def extract_words(text)
      text.gsub(/[^\p{L}\s]/, ' ')
          .split(/\s+/)
          .reject(&:empty?)
    end

    def load_stop_words
      @stop_words ||= begin
        stop_words_file = Rails.root.join('stop-words.txt')
        if File.exist?(stop_words_file)
          File.readlines(stop_words_file).map(&:strip).reject(&:empty?)
        else
          []
        end
      end
    end
  end
end


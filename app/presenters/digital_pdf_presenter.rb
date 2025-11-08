# frozen_string_literal: true

# Presenter for Digital PDF generation
# Encapsulates all view logic and calculations for digital media PDF reports
# Follows the same pattern as TwitterDashboardPresenter and FacebookSentimentPresenter
class DigitalPdfPresenter
  include ActionView::Helpers::NumberHelper

  attr_reader :topic, :days_range, :data

  # Conservative reach multiplier for digital media
  # Assumes each interaction represents ~3 unique viewers
  # Based on industry research for digital news consumption patterns
  REACH_MULTIPLIER = 3

  # Initialize presenter with topic data
  #
  # @param data [Hash] Data from DigitalDashboardServices::PdfService
  # @param topic [Topic] The topic being analyzed
  # @param days_range [Integer] Number of days in the report period
  def initialize(data:, topic: nil, days_range: nil)
    @data = data
    @topic = topic
    @days_range = days_range
  end

  # Get entries count from data
  # @return [Integer] Number of entries
  def entries_count
    @entries_count ||= data.dig(:topic_data, :entries_count) ||
                       data.dig(:topic_data, :total_entries) ||
                       0
  end

  # Get total interactions count
  # @return [Integer] Total interactions
  def interactions_count
    @interactions_count ||= data.dig(:topic_data, :entries_total_sum) ||
                            data.dig(:topic_data, :total_interactions) ||
                            0
  end

  # Calculate estimated reach using conservative multiplier
  # Digital media reach is estimated as interactions * 3
  # This is a conservative estimate based on industry standards
  #
  # @return [Integer] Estimated reach
  def estimated_reach
    @estimated_reach ||= interactions_count * REACH_MULTIPLIER
  end

  # Calculate average interactions per entry
  # @return [Integer] Average interactions (rounded)
  def average_interactions
    return 0 if entries_count.zero?
    @average_interactions ||= (interactions_count.to_f / entries_count).round
  end

  # Format entries count with delimiter
  # @return [String] Formatted count
  def formatted_entries_count
    number_with_delimiter(entries_count, delimiter: '.')
  end

  # Format interactions count with delimiter
  # @return [String] Formatted count
  def formatted_interactions_count
    number_with_delimiter(interactions_count, delimiter: '.')
  end

  # Format estimated reach with delimiter
  # @return [String] Formatted reach
  def formatted_estimated_reach
    number_with_delimiter(estimated_reach, delimiter: '.')
  end

  # Format average interactions with delimiter
  # @return [String] Formatted average
  def formatted_average_interactions
    number_with_delimiter(average_interactions, delimiter: '.')
  end

  # Get sentiment data for positive entries
  # @return [Hash] Count and interactions for positive sentiment
  def positive_sentiment
    {
      count: data.dig(:percentages, :positives) || 0,
      interactions: data.dig(:topic_data, :entries_polarity_sums, 1) || 0
    }
  end

  # Get sentiment data for neutral entries
  # @return [Hash] Count and interactions for neutral sentiment
  def neutral_sentiment
    {
      count: data.dig(:percentages, :neutrals) || 0,
      interactions: data.dig(:topic_data, :entries_polarity_sums, 0) || 0
    }
  end

  # Get sentiment data for negative entries
  # @return [Hash] Count and interactions for negative sentiment
  def negative_sentiment
    {
      count: data.dig(:percentages, :negatives) || 0,
      interactions: data.dig(:topic_data, :entries_polarity_sums, 2) || 0
    }
  end

  # Check if sentiment data exists
  # @return [Boolean] True if sentiment data present
  def has_sentiment_data?
    data.dig(:topic_data, :entries_polarity_counts).present?
  end

  # Check if site data exists
  # @return [Boolean] True if site data present
  def has_site_data?
    data.dig(:topic_data, :site_counts).present? &&
      data.dig(:topic_data, :site_counts).any?
  end

  # Check if tag data exists
  # @return [Boolean] True if tag data present
  def has_tag_data?
    data.dig(:tags_and_words, :tags_count).present? &&
      data.dig(:tags_and_words, :tags_count).any?
  end

  # Check if word analysis data exists
  # @return [Boolean] True if word data present
  def has_word_data?
    data.dig(:tags_and_words, :word_occurrences).present? &&
      data.dig(:tags_and_words, :word_occurrences).any?
  end

  # Check if bigram data exists
  # @return [Boolean] True if bigram data present
  def has_bigram_data?
    data.dig(:tags_and_words, :bigram_occurrences).present? &&
      data.dig(:tags_and_words, :bigram_occurrences).any?
  end

  # Get chart data for entries counts
  # @return [Hash] Date => count mapping
  def chart_entries_counts
    data.dig(:chart_data, :chart_entries_counts) || {}
  end

  # Get chart data for entries sums
  # @return [Hash] Date => sum mapping
  def chart_entries_sums
    data.dig(:chart_data, :chart_entries_sums) || {}
  end

  # Get chart data for sentiment counts
  # @return [Hash] [sentiment, date] => count mapping
  def chart_sentiment_counts
    data.dig(:chart_data, :chart_entries_sentiments_counts) || {}
  end

  # Get chart data for sentiment sums
  # @return [Hash] [sentiment, date] => sum mapping
  def chart_sentiment_sums
    data.dig(:chart_data, :chart_entries_sentiments_sums) || {}
  end

  # Get site counts for pie chart
  # @return [Hash] Site name => count
  def site_counts
    data.dig(:topic_data, :site_counts) || {}
  end

  # Get site interaction sums for pie chart
  # @return [Hash] Site name => interactions
  def site_sums
    data.dig(:topic_data, :site_sums) || {}
  end

  # Get tag counts
  # @return [Hash] Tag name => count
  def tag_counts
    data.dig(:tags_and_words, :tags_count) || {}
  end

  # Get tag interactions
  # @return [Hash] Tag name => interactions
  def tag_interactions
    data.dig(:tags_and_words, :tags_interactions) || {}
  end

  # Get word occurrences
  # @return [Hash] Word => count
  def word_occurrences
    data.dig(:tags_and_words, :word_occurrences) || {}
  end

  # Get bigram occurrences
  # @return [Hash] Bigram => count
  def bigram_occurrences
    data.dig(:tags_and_words, :bigram_occurrences) || {}
  end

  # Get entries for top content display
  # Handles different types of @entries (Relation, Struct, Array)
  #
  # @param entries [ActiveRecord::Relation, Struct, Array] Entries data
  # @param limit [Integer] Maximum number of entries to return
  # @return [Array<Entry>] Top entries sorted by interactions
  def top_entries(entries, limit: 15)
    if entries.respond_to?(:relation)
      # It's a Struct wrapper from PDF service
      entries.relation.includes(:site).order(total_count: :desc).limit(limit)
    elsif entries.respond_to?(:limit)
      # It's an ActiveRecord Relation
      entries.includes(:site).order(total_count: :desc).limit(limit)
    else
      # It's an Array
      entries.sort_by { |e| -e.total_count.to_i }.take(limit)
    end
  end

  # Get KPI metrics for PDF display
  # @return [Array<Hash>] Array of metric hashes
  def kpi_metrics
    [
      {
        label: 'Notas',
        value: formatted_entries_count,
        icon: '📰'
      },
      {
        label: 'Interacciones',
        value: formatted_interactions_count,
        icon: '📊'
      },
      {
        label: 'Alcance Est.',
        value: formatted_estimated_reach,
        icon: '🎯'
      },
      {
        label: 'Promedio',
        value: formatted_average_interactions,
        icon: '📈'
      }
    ]
  end

  # Get reach methodology explanation
  # @return [String] Explanation text
  def reach_methodology
    "El alcance estimado se calcula de forma conservadora (#{REACH_MULTIPLIER}x las interacciones). " \
    'Esto asume que cada interacción representa aproximadamente 3 lectores únicos.'
  end
end


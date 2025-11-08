# frozen_string_literal: true

# Concern for PDF caching functionality
# Provides intelligent caching for PDF generation to improve performance
module PdfCacheable
  extend ActiveSupport::Concern

  # Cache durations based on PDF type and complexity
  PDF_CACHE_DURATIONS = {
    digital: PdfConstants::PDF_CACHE_DURATION,
    facebook: PdfConstants::PDF_CACHE_DURATION,
    twitter: PdfConstants::PDF_CACHE_DURATION,
    general: 1.hour
  }.freeze

  class_methods do
    # Generate cache key for PDF
    #
    # @param type [Symbol] PDF type (:digital, :facebook, :twitter)
    # @param topic_id [Integer] Topic ID
    # @param days_range [Integer] Number of days
    # @param options [Hash] Additional cache key components
    # @return [String] Cache key
    def pdf_cache_key(type:, topic_id:, days_range:, **options)
      base_key = "pdf/#{type}/topic_#{topic_id}/days_#{days_range}"

      # Add optional components
      extra = options.map { |k, v| "#{k}_#{v}" }.join('/')
      cache_key = extra.present? ? "#{base_key}/#{extra}" : base_key

      # Add timestamp component for daily refresh
      "#{cache_key}/#{Date.current.to_s(:number)}"
    end
  end

  # Get cached PDF data or generate new
  #
  # @param type [Symbol] PDF type
  # @param topic_id [Integer] Topic ID
  # @param days_range [Integer] Number of days
  # @param options [Hash] Additional options
  # @yield Block that generates the PDF data
  # @return [Object] Cached or generated data
  def fetch_cached_pdf(type:, topic_id:, days_range:, **options, &block)
    cache_key = self.class.pdf_cache_key(
      type: type,
      topic_id: topic_id,
      days_range: days_range,
      **options
    )

    cache_duration = PDF_CACHE_DURATIONS[type] || PDF_CACHE_DURATIONS[:general]

    Rails.cache.fetch(cache_key, expires_in: cache_duration, &block)
  end

  # Expire PDF cache for a specific topic
  #
  # @param type [Symbol] PDF type
  # @param topic_id [Integer] Topic ID
  # @param days_range [Integer] Number of days
  def expire_pdf_cache(type:, topic_id:, days_range: nil)
    if days_range
      # Expire specific cache
      cache_key = self.class.pdf_cache_key(
        type: type,
        topic_id: topic_id,
        days_range: days_range
      )
      Rails.cache.delete(cache_key)
    else
      # Expire all caches for this topic
      pattern = "pdf/#{type}/topic_#{topic_id}/*"
      Rails.cache.delete_matched(pattern)
    end
  end

  # Check if PDF cache exists
  #
  # @param type [Symbol] PDF type
  # @param topic_id [Integer] Topic ID
  # @param days_range [Integer] Number of days
  # @return [Boolean] True if cache exists
  def pdf_cached?(type:, topic_id:, days_range:)
    cache_key = self.class.pdf_cache_key(
      type: type,
      topic_id: topic_id,
      days_range: days_range
    )

    Rails.cache.exist?(cache_key)
  end

  # Get cache statistics for a PDF
  #
  # @param type [Symbol] PDF type
  # @param topic_id [Integer] Topic ID
  # @param days_range [Integer] Number of days
  # @return [Hash] Cache statistics
  def pdf_cache_stats(type:, topic_id:, days_range:)
    cache_key = self.class.pdf_cache_key(
      type: type,
      topic_id: topic_id,
      days_range: days_range
    )

    {
      exists: Rails.cache.exist?(cache_key),
      key: cache_key,
      expires_in: PDF_CACHE_DURATIONS[type],
      type: type
    }
  end
end


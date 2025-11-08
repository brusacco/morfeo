# frozen_string_literal: true

# Helper for sentiment trend charts
# Provides consistent configuration for sentiment visualization across dashboards
module SentimentChartHelper
  # Chart configuration constants
  DEFAULT_CHART_HEIGHT = 300
  DEFAULT_LINE_WIDTH = 3
  DEFAULT_MARKER_RADIUS = 4
  DEFAULT_LEGEND_ALIGNMENT = 'center'
  DEFAULT_LEGEND_VERTICAL_ALIGNMENT = 'bottom'

  # Sentiment colors (consistent across all dashboards)
  SENTIMENT_COLORS = {
    positive: '#10B981', # Tailwind green-500
    neutral: '#9CA3AF',  # Tailwind gray-400
    negative: '#EF4444'  # Tailwind red-500
  }.freeze

  # Pre-computed color array for performance (frozen)
  SENTIMENT_COLOR_ARRAY = [
    SENTIMENT_COLORS[:positive],
    SENTIMENT_COLORS[:neutral],
    SENTIMENT_COLORS[:negative]
  ].freeze

  # Sentiment label keys for I18n
  SENTIMENT_KEYS = %i[positive neutral negative].freeze

  # Generate sentiment line chart configuration
  # This replaces area charts with line charts for better readability
  #
  # @param options [Hash] Optional configuration overrides
  # @option options [Integer] :height Chart height in pixels
  # @option options [Integer] :line_width Line thickness in pixels
  # @option options [Integer] :marker_radius Marker radius in pixels
  # @option options [Boolean] :legend Show/hide legend
  # @return [Hash] Chartkick library configuration
  def sentiment_line_chart_config(options = {})
    {
      chart: { 
        height: options[:height] || DEFAULT_CHART_HEIGHT 
      },
      plotOptions: {
        series: {
          lineWidth: options[:line_width] || DEFAULT_LINE_WIDTH,
          marker: {
            enabled: true,
            radius: options[:marker_radius] || DEFAULT_MARKER_RADIUS
          }
        }
      },
      tooltip: {
        shared: true,
        crosshairs: true
      },
      legend: {
        enabled: options[:legend] != false,
        align: DEFAULT_LEGEND_ALIGNMENT,
        verticalAlign: DEFAULT_LEGEND_VERTICAL_ALIGNMENT
      }
    }
  end

  # Get sentiment colors array (memoized for performance)
  # @return [Array<String>] Frozen array of hex color codes [positive, neutral, negative]
  def sentiment_colors
    SENTIMENT_COLOR_ARRAY
  end

  # Get sentiment legend data structure
  # Returns data instead of HTML for better separation of concerns
  # @return [Array<Hash>] Array of {label: String, color: String, key: Symbol}
  def sentiment_legend_data
    SENTIMENT_KEYS.map do |key|
      {
        label: I18n.t("sentiment.#{key}"),
        color: SENTIMENT_COLORS[key],
        key: key
      }
    end
  end

  # Generate sentiment legend HTML (deprecated - use sentiment_legend_data instead)
  # @deprecated Use {#sentiment_legend_data} and render in view for better separation
  # @return [String] HTML for sentiment legend
  def sentiment_legend_html
    content_tag(:div, class: 'flex items-center space-x-2 text-sm text-gray-500') do
      sentiment_legend_data.map do |item|
        sentiment_legend_item_html(item[:label], item[:color])
      end.join.html_safe
    end
  end

  private

  # Generate individual legend item HTML
  # @param label [String] Display label
  # @param color [String] Hex color code
  # @return [String] HTML string
  def sentiment_legend_item_html(label, color)
    content_tag(:div, class: 'flex items-center') do
      concat(content_tag(:div, '', class: 'w-3 h-3 rounded-full mr-1', style: "background-color: #{color}"))
      concat(content_tag(:span, label))
    end
  end
end


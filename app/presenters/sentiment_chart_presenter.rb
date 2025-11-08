# frozen_string_literal: true

# Presenter for sentiment trend charts
# Encapsulates chart configuration and reduces complexity in views/partials
class SentimentChartPresenter
  attr_reader :title, :icon, :icon_color, :chart_data_counts, :chart_data_sums

  # Initialize presenter with chart configuration
  #
  # @param options [Hash] Configuration options
  # @option options [String] :title Section title (required)
  # @option options [String] :icon FontAwesome icon class (required)
  # @option options [String] :icon_color Tailwind color class (required)
  # @option options [Hash] :chart_data_counts Data for count/quantity chart (required)
  # @option options [Hash] :chart_data_sums Data for sum/interactions chart (required)
  # @option options [String] :chart_id_prefix Prefix for chart IDs (default: 'sentiment')
  # @option options [String] :count_label Label for first chart (default: I18n)
  # @option options [String] :sum_label Label for second chart (default: I18n)
  # @option options [String] :controller_name Stimulus controller name (optional)
  # @option options [Integer] :topic_id Topic ID for data reloading (optional)
  # @option options [String] :url_path URL for AJAX data loading (optional)
  def initialize(options)
    @title = options[:title]
    @icon = options[:icon]
    @icon_color = options[:icon_color]
    @chart_data_counts = options[:chart_data_counts]
    @chart_data_sums = options[:chart_data_sums]
    @chart_id_prefix = options.fetch(:chart_id_prefix, 'sentiment')
    @count_label = options[:count_label]
    @sum_label = options[:sum_label]
    @controller_name = options[:controller_name]
    @topic_id = options[:topic_id]
    @url_path = options[:url_path]
  end

  # Chart ID for count/quantity chart
  # @return [String] Unique chart ID
  def count_chart_id
    @count_chart_id ||= "#{@chart_id_prefix}CountChart"
  end

  # Chart ID for sum/interactions chart
  # @return [String] Unique chart ID
  def sum_chart_id
    @sum_chart_id ||= "#{@chart_id_prefix}SumChart"
  end

  # Label for count/quantity chart
  # @return [String] Chart label (I18n or custom)
  def count_label
    @count_label || I18n.t('sentiment.charts.count_label')
  end

  # Label for sum/interactions chart
  # @return [String] Chart label (I18n or custom)
  def sum_label
    @sum_label || I18n.t('sentiment.charts.sum_label')
  end

  # Check if Stimulus controller integration is enabled
  # @return [Boolean] True if controller, topic_id, and url_path are present
  def stimulus_enabled?
    @controller_name.present? && @topic_id.present? && @url_path.present?
  end

  # Get Stimulus data attributes for count chart
  # @return [Hash] Hash of data attributes for HTML
  def count_chart_stimulus_attributes
    stimulus_attributes_for(count_chart_id)
  end

  # Get Stimulus data attributes for sum chart
  # @return [Hash] Hash of data attributes for HTML
  def sum_chart_stimulus_attributes
    stimulus_attributes_for(sum_chart_id)
  end

  private

  # Generate Stimulus data attributes for a specific chart
  # @param chart_id [String] Chart identifier
  # @return [Hash] Hash of data attributes, empty if Stimulus not enabled
  def stimulus_attributes_for(chart_id)
    return {} unless stimulus_enabled?

    {
      'data-controller': @controller_name,
      "data-#{@controller_name}-id-value": chart_id,
      "data-#{@controller_name}-url-value": @url_path,
      "data-#{@controller_name}-topic-id-value": @topic_id
    }
  end
end


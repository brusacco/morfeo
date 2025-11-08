# frozen_string_literal: true

# ChartsHelper
# 
# Provides helper methods for rendering charts consistently across the application.
# Handles Highcharts configuration, clickable charts, and tooltip formatting.
#
# @example Basic usage
#   <%= render_clickable_chart(@data, type: :column, label: 'Publicaciones', color: :primary) %>
#
# @example With custom options
#   <%= render_clickable_chart(@data,
#         type: :column,
#         label: 'Interacciones',
#         color: :success,
#         chart_id: 'myChart',
#         url: entries_data_topics_path,
#         topic_id: @topic.id) %>
#
module ChartsHelper
  # Renders a clickable column chart with consistent configuration
  #
  # @param data [Hash] Chart data (from groupdate or manual hash)
  # @param options [Hash] Chart configuration options
  # @option options [String] :chart_id Unique chart identifier (required for clickable charts)
  # @option options [String] :url URL for loading entries on click
  # @option options [Integer] :topic_id Topic ID for filtering
  # @option options [String] :label Label for tooltip (e.g., 'Publicaciones', 'Interacciones')
  # @option options [Symbol] :color Color from CHART_CONFIG[:colors] (default: :primary)
  # @option options [String] :xtitle X-axis title
  # @option options [String] :ytitle Y-axis title
  # @option options [Boolean] :clickable Enable click events (default: true if url present)
  # @option options [Boolean] :title For title-based filtering (default: false)
  # @option options [Hash] :library Additional Highcharts configuration
  # @return [String] HTML string with chart
  def render_clickable_chart(data, **options)
    chart_type = options.delete(:type) || :column
    
    # Determine if chart should be clickable (default: true if url present)
    clickable = options[:clickable] != false && options[:url].present?
    
    chart_options = build_chart_options(options)
    wrapper_options = build_wrapper_options(options)
    
    content_tag(:div, **wrapper_options) do
      concat send("#{chart_type}_chart", data, **chart_options)
      concat render('home/modal', graph_id: options[:chart_id], controller_name: 'topics') if clickable
    end
  end

  # Renders a clickable column chart (alias for render_clickable_chart)
  #
  # @see #render_clickable_chart
  def render_column_chart(data, **options)
    render_clickable_chart(data, type: :column, **options)
  end

  # Renders a clickable area chart with stacking support
  #
  # @param data [Hash] Chart data
  # @param options [Hash] Chart configuration options
  # @option options [Boolean] :stacked Enable stacking (default: false)
  # @option options [Array<Symbol>] :colors Array of color keys for multiple series
  # @see #render_clickable_chart for other options
  def render_area_chart(data, **options)
    options[:library] ||= {}
    options[:library][:chart] ||= {}
    options[:library][:chart][:type] = 'area'
    
    if options.delete(:stacked)
      options[:library][:plotOptions] ||= {}
      options[:library][:plotOptions][:area] ||= {}
      options[:library][:plotOptions][:area][:stacking] = 'normal'
    end
    
    render_clickable_chart(data, type: :area, **options)
  end

  # Renders a pie chart (non-clickable)
  #
  # @param data [Hash] Chart data
  # @param options [Hash] Chart configuration options
  # @option options [Boolean] :donut Enable donut chart (default: false)
  # @option options [String] :suffix Suffix for values (e.g., '%')
  def render_pie_chart(data, **options)
    chart_options = {
      donut: options.delete(:donut) || false,
      suffix: options.delete(:suffix) || '',
      library: CHART_CONFIG[:defaults][:library].deep_dup
    }
    
    pie_chart(data, chart_options)
  end

  # Gets a color hex code from the config
  #
  # @param color_key [Symbol] Color key from CHART_CONFIG[:colors]
  # @return [String] Hex color code
  def chart_color(color_key)
    CHART_CONFIG[:colors][color_key] || CHART_CONFIG[:colors][:primary]
  end

  # Gets multiple colors for multi-series charts
  #
  # @param color_keys [Array<Symbol>] Array of color keys
  # @return [Array<String>] Array of hex color codes
  def chart_colors(*color_keys)
    color_keys.flatten.map { |key| chart_color(key) }
  end

  # Builds Highcharts library configuration for sentiment charts
  #
  # @return [Hash] Highcharts configuration for sentiment colors
  def sentiment_chart_config
    {
      colors: [
        chart_color(:success),  # Positive (green)
        chart_color(:gray),     # Neutral (gray)
        chart_color(:danger)    # Negative (red)
      ],
      plotOptions: {
        series: {
          stacking: 'normal',
          dataLabels: { enabled: false }
        }
      }
    }
  end

  private

  # Builds complete chart options hash
  #
  # @param options [Hash] User-provided options
  # @return [Hash] Complete Highcharts configuration
  def build_chart_options(options)
    label = options[:label]
    color = options[:color] || :primary
    
    chart_opts = {
      id: options[:chart_id],
      xtitle: options[:xtitle],
      ytitle: options[:ytitle],
      adapter: 'highcharts',
      thousands: '.',
      colors: [chart_color(color)],
      library: build_library_config(label, options[:library])
    }
    
    # Remove nil values
    chart_opts.compact
  end

  # Builds Highcharts library configuration
  #
  # @param label [String] Label for tooltip
  # @param custom_config [Hash] Custom library configuration to merge
  # @return [Hash] Complete library configuration
  def build_library_config(label, custom_config = {})
    base_config = CHART_CONFIG[:defaults][:library].deep_dup
    
    # Add tooltip configuration if label provided
    if label.present?
      base_config[:tooltip] = {
        pointFormat: "<b>{point.y}</b> #{label}"
      }
    end
    
    # Merge custom configuration
    base_config.deep_merge(custom_config || {})
  end

  # Builds wrapper div options with data attributes
  #
  # @param options [Hash] Chart options
  # @return [Hash] HTML attributes for wrapper div
  def build_wrapper_options(options)
    wrapper = {
      class: 'w-full overflow-hidden'
    }
    
    # Add data attributes for clickable charts
    if options[:clickable] != false && options[:url].present?
      wrapper[:data] = {
        controller: 'topics',
        topics_id_value: options[:chart_id],
        topics_url_value: options[:url],
        topics_topic_id_value: options[:topic_id],
        topics_title_value: options[:title] || false
      }
    end
    
    wrapper
  end
end


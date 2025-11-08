# frozen_string_literal: true

# Chart configuration constants
# Centralized configuration for all charts across the application
CHART_CONFIG = {
  # Color palette aligned with Tailwind CSS design system
  colors: {
    primary: '#3B82F6',    # blue-500
    success: '#10B981',    # green-500
    purple: '#8B5CF6',     # purple-500
    warning: '#F59E0B',    # amber-500
    danger: '#EF4444',     # red-500
    indigo: '#6366F1',     # indigo-500
    sky: '#0EA5E9',        # sky-500
    gray: '#9CA3AF'        # gray-400
  }.freeze,

  # Default chart options
  defaults: {
    thousands: '.',
    adapter: 'highcharts',
    library: {
      chart: {
        style: {
          fontFamily: 'system-ui, -apple-system, sans-serif'
        }
      },
      plotOptions: {
        series: {
          dataLabels: {
            enabled: true
          }
        }
      },
      credits: {
        enabled: false  # Disable Highcharts.com watermark
      }
    }
  }.freeze,

  # Tooltip formats for different chart types
  tooltips: {
    count: '<b>{point.y}</b>',
    percentage: '<b>{point.y}%</b>',
    with_label: '<b>{point.y}</b> {label}'
  }.freeze
}.freeze


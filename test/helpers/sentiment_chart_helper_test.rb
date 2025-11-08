# frozen_string_literal: true

require 'test_helper'

class SentimentChartHelperTest < ActionView::TestCase
  # === Color Tests ===
  
  test 'sentiment_colors returns correct frozen array' do
    colors = sentiment_colors
    assert_equal 3, colors.length
    assert_equal '#10B981', colors[0] # Positive - Green
    assert_equal '#9CA3AF', colors[1] # Neutral - Gray
    assert_equal '#EF4444', colors[2] # Negative - Red
    assert colors.frozen?, 'Color array should be frozen for performance'
  end
  
  test 'SENTIMENT_COLORS constant is frozen' do
    assert SentimentChartHelper::SENTIMENT_COLORS.frozen?
  end
  
  test 'SENTIMENT_COLORS contains correct keys' do
    colors = SentimentChartHelper::SENTIMENT_COLORS
    assert_includes colors.keys, :positive
    assert_includes colors.keys, :neutral
    assert_includes colors.keys, :negative
  end
  
  test 'SENTIMENT_COLOR_ARRAY constant is frozen' do
    assert SentimentChartHelper::SENTIMENT_COLOR_ARRAY.frozen?
  end

  # === Configuration Tests ===
  
  test 'sentiment_line_chart_config returns valid configuration' do
    config = sentiment_line_chart_config
    
    assert_not_nil config[:chart]
    assert_equal SentimentChartHelper::DEFAULT_CHART_HEIGHT, config[:chart][:height]
    
    assert_not_nil config[:plotOptions]
    assert_equal SentimentChartHelper::DEFAULT_LINE_WIDTH, config[:plotOptions][:series][:lineWidth]
    assert config[:plotOptions][:series][:marker][:enabled]
    assert_equal SentimentChartHelper::DEFAULT_MARKER_RADIUS, config[:plotOptions][:series][:marker][:radius]
    
    assert_not_nil config[:tooltip]
    assert config[:tooltip][:shared]
    assert config[:tooltip][:crosshairs]
    
    assert_not_nil config[:legend]
    assert config[:legend][:enabled]
    assert_equal 'center', config[:legend][:align]
    assert_equal 'bottom', config[:legend][:verticalAlign]
  end

  test 'sentiment_line_chart_config accepts custom height' do
    config = sentiment_line_chart_config(height: 400)
    assert_equal 400, config[:chart][:height]
  end

  test 'sentiment_line_chart_config accepts custom line width' do
    config = sentiment_line_chart_config(line_width: 5)
    assert_equal 5, config[:plotOptions][:series][:lineWidth]
  end

  test 'sentiment_line_chart_config accepts custom marker radius' do
    config = sentiment_line_chart_config(marker_radius: 6)
    assert_equal 6, config[:plotOptions][:series][:marker][:radius]
  end
  
  test 'sentiment_line_chart_config can disable legend' do
    config = sentiment_line_chart_config(legend: false)
    assert_not config[:legend][:enabled]
  end
  
  test 'sentiment_line_chart_config handles nil options gracefully' do
    assert_nothing_raised do
      sentiment_line_chart_config(nil)
    end
  end
  
  test 'sentiment_line_chart_config handles empty options' do
    config = sentiment_line_chart_config({})
    assert_equal SentimentChartHelper::DEFAULT_CHART_HEIGHT, config[:chart][:height]
  end

  # === Legend Data Tests ===
  
  test 'sentiment_legend_data returns array with correct structure' do
    data = sentiment_legend_data
    
    assert_instance_of Array, data
    assert_equal 3, data.length
    
    data.each do |item|
      assert_includes item.keys, :label
      assert_includes item.keys, :color
      assert_includes item.keys, :key
      assert_instance_of String, item[:label]
      assert_instance_of String, item[:color]
      assert_instance_of Symbol, item[:key]
    end
  end
  
  test 'sentiment_legend_data contains all sentiment types' do
    data = sentiment_legend_data
    keys = data.map { |item| item[:key] }
    
    assert_includes keys, :positive
    assert_includes keys, :neutral
    assert_includes keys, :negative
  end
  
  test 'sentiment_legend_data uses I18n translations' do
    I18n.with_locale(:es) do
      data = sentiment_legend_data
      
      positive_item = data.find { |item| item[:key] == :positive }
      assert_equal I18n.t('sentiment.positive'), positive_item[:label]
    end
  end

  # === Legacy HTML Method Tests ===
  
  test 'sentiment_legend_html generates correct HTML structure' do
    html = sentiment_legend_html
    
    assert_match /Positivo/, html
    assert_match /Neutro/, html
    assert_match /Negativo/, html
    assert_match /flex items-center space-x-2/, html
  end
  
  test 'sentiment_legend_html includes color divs' do
    html = sentiment_legend_html
    assert_match /background-color: #10B981/, html
    assert_match /background-color: #9CA3AF/, html
    assert_match /background-color: #EF4444/, html
  end

  # === Constants Tests ===
  
  test 'DEFAULT_CHART_HEIGHT constant exists and has correct value' do
    assert_equal 300, SentimentChartHelper::DEFAULT_CHART_HEIGHT
  end
  
  test 'DEFAULT_LINE_WIDTH constant exists and has correct value' do
    assert_equal 3, SentimentChartHelper::DEFAULT_LINE_WIDTH
  end
  
  test 'DEFAULT_MARKER_RADIUS constant exists and has correct value' do
    assert_equal 4, SentimentChartHelper::DEFAULT_MARKER_RADIUS
  end
  
  test 'SENTIMENT_KEYS constant is frozen' do
    assert SentimentChartHelper::SENTIMENT_KEYS.frozen?
  end
end


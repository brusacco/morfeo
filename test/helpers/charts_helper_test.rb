# frozen_string_literal: true

require 'test_helper'

class ChartsHelperTest < ActionView::TestCase
  include ChartsHelper

  # ============================================
  # chart_color tests
  # ============================================

  test 'chart_color returns correct hex code for primary' do
    assert_equal '#3B82F6', chart_color(:primary)
  end

  test 'chart_color returns correct hex code for success' do
    assert_equal '#10B981', chart_color(:success)
  end

  test 'chart_color returns correct hex code for danger' do
    assert_equal '#EF4444', chart_color(:danger)
  end

  test 'chart_color falls back to primary for unknown color' do
    assert_equal '#3B82F6', chart_color(:unknown_color)
  end

  # ============================================
  # chart_colors tests
  # ============================================

  test 'chart_colors returns array of hex codes' do
    colors = chart_colors(:success, :danger)
    assert_equal ['#10B981', '#EF4444'], colors
  end

  test 'chart_colors handles single color' do
    colors = chart_colors(:primary)
    assert_equal ['#3B82F6'], colors
  end

  test 'chart_colors handles array input' do
    colors = chart_colors([:success, :warning, :danger])
    expected = ['#10B981', '#F59E0B', '#EF4444']
    assert_equal expected, colors
  end

  # ============================================
  # sentiment_chart_config tests
  # ============================================

  test 'sentiment_chart_config returns correct colors' do
    config = sentiment_chart_config
    expected_colors = ['#10B981', '#9CA3AF', '#EF4444'] # green, gray, red
    assert_equal expected_colors, config[:colors]
  end

  test 'sentiment_chart_config includes stacking configuration' do
    config = sentiment_chart_config
    assert_equal 'normal', config[:plotOptions][:series][:stacking]
  end

  test 'sentiment_chart_config disables data labels' do
    config = sentiment_chart_config
    assert_equal false, config[:plotOptions][:series][:dataLabels][:enabled]
  end

  # ============================================
  # Private method tests (via public interface)
  # ============================================

  test 'build_chart_options includes required fields' do
    options = {
      chart_id: 'testChart',
      label: 'Test Label',
      color: :primary,
      xtitle: 'X Axis',
      ytitle: 'Y Axis'
    }
    
    result = send(:build_chart_options, options)
    
    assert_equal 'testChart', result[:id]
    assert_equal 'X Axis', result[:xtitle]
    assert_equal 'Y Axis', result[:ytitle]
    assert_equal 'highcharts', result[:adapter]
    assert_equal '.', result[:thousands]
    assert_equal ['#3B82F6'], result[:colors]
  end

  test 'build_chart_options defaults to primary color' do
    options = { chart_id: 'test', label: 'Test' }
    result = send(:build_chart_options, options)
    assert_equal ['#3B82F6'], result[:colors]
  end

  test 'build_library_config includes tooltip when label provided' do
    config = send(:build_library_config, 'Publications')
    assert_equal '<b>{point.y}</b> Publications', config[:tooltip][:pointFormat]
  end

  test 'build_library_config excludes tooltip when no label' do
    config = send(:build_library_config, nil)
    assert_nil config[:tooltip]
  end

  test 'build_library_config merges custom configuration' do
    custom = { chart: { backgroundColor: '#fff' } }
    config = send(:build_library_config, 'Test', custom)
    assert_equal '#fff', config[:chart][:backgroundColor]
  end

  test 'build_library_config preserves default configuration' do
    config = send(:build_library_config, 'Test')
    assert config[:plotOptions][:series][:dataLabels][:enabled]
    assert_equal false, config[:credits][:enabled]
  end

  test 'build_wrapper_options includes data attributes when clickable' do
    options = {
      url: '/test/path',
      chart_id: 'testChart',
      topic_id: 123,
      clickable: true
    }
    
    result = send(:build_wrapper_options, options)
    
    assert_equal 'w-full overflow-hidden', result[:class]
    assert_equal 'topics', result[:data][:controller]
    assert_equal 'testChart', result[:data][:topics_id_value]
    assert_equal '/test/path', result[:data][:topics_url_value]
    assert_equal 123, result[:data][:topics_topic_id_value]
    assert_equal false, result[:data][:topics_title_value]
  end

  test 'build_wrapper_options omits data attributes when not clickable' do
    options = {
      clickable: false,
      url: '/test/path'
    }
    
    result = send(:build_wrapper_options, options)
    
    assert_equal 'w-full overflow-hidden', result[:class]
    assert_nil result[:data]
  end

  test 'build_wrapper_options includes title value when provided' do
    options = {
      url: '/test/path',
      chart_id: 'testChart',
      topic_id: 123,
      title: true
    }
    
    result = send(:build_wrapper_options, options)
    assert_equal true, result[:data][:topics_title_value]
  end

  # ============================================
  # Integration tests (render methods)
  # ============================================

  test 'render_column_chart generates valid HTML with clickable wrapper' do
    data = { '2024-01-01' => 10, '2024-01-02' => 20 }
    
    html = render_column_chart(data,
      chart_id: 'testChart',
      url: '/test/path',
      topic_id: 123,
      label: 'Test',
      color: :primary,
      xtitle: 'Date',
      ytitle: 'Count'
    )
    
    assert_includes html, 'w-full overflow-hidden'
    assert_includes html, 'data-controller="topics"'
    assert_includes html, 'data-topics-id-value="testChart"'
  end

  test 'render_area_chart with stacking includes correct config' do
    data = { '2024-01-01' => 10, '2024-01-02' => 20 }
    
    html = render_area_chart(data,
      chart_id: 'areaChart',
      url: '/test/path',
      topic_id: 123,
      label: 'Test',
      stacked: true
    )
    
    assert_includes html, 'w-full overflow-hidden'
    # Chart should be rendered (actual rendering tested by Chartkick)
    assert_not_nil html
  end

  test 'render_pie_chart generates non-clickable chart' do
    data = { 'Category A' => 30, 'Category B' => 70 }
    
    html = render_pie_chart(data, donut: true, suffix: '%')
    
    # Should not include clickable wrapper
    assert_not_includes html, 'data-controller="topics"'
    # Should be rendered
    assert_not_nil html
  end

  # ============================================
  # Error handling tests
  # ============================================

  test 'render_column_chart handles empty data gracefully' do
    data = {}
    
    html = render_column_chart(data,
      chart_id: 'emptyChart',
      url: '/test/path',
      topic_id: 123,
      label: 'Empty'
    )
    
    assert_not_nil html
  end

  test 'render_column_chart works without optional parameters' do
    data = { '2024-01-01' => 10 }
    
    html = render_column_chart(data,
      chart_id: 'minimalChart',
      url: '/test/path',
      topic_id: 123,
      label: 'Minimal'
    )
    
    assert_not_nil html
  end
end


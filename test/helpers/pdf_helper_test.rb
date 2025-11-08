# frozen_string_literal: true

require 'test_helper'

class PdfHelperTest < ActionView::TestCase
  test 'pdf_format_number formats nil as 0' do
    assert_equal '0', pdf_format_number(nil)
  end

  test 'pdf_format_number formats zero' do
    assert_equal '0', pdf_format_number(0)
  end

  test 'pdf_format_number formats small numbers' do
    assert_equal '123', pdf_format_number(123)
  end

  test 'pdf_format_number formats thousands with dot separator' do
    assert_equal '1.234', pdf_format_number(1234)
  end

  test 'pdf_format_number formats millions' do
    assert_equal '1.234.567', pdf_format_number(1_234_567)
  end

  test 'pdf_format_number handles large numbers' do
    assert_equal '12.345.678', pdf_format_number(12_345_678)
  end

  test 'pdf_date_range with days_range' do
    result = pdf_date_range(days_range: 7)
    assert_includes result, 'Últimos 7 días'
  end

  test 'pdf_date_range with start and end dates' do
    start_date = Date.new(2025, 1, 1)
    end_date = Date.new(2025, 1, 7)
    
    result = pdf_date_range(start_date: start_date, end_date: end_date)
    assert_equal '01/01/2025 - 07/01/2025', result
  end

  test 'pdf_date_range defaults when no params' do
    result = pdf_date_range
    assert_equal 'Período analizado', result
  end

  test 'pdf_sentiment_emoji returns correct emoji for digital system' do
    assert_equal '😊', pdf_sentiment_emoji(1, system: :digital)
    assert_equal '😐', pdf_sentiment_emoji(0, system: :digital)
    assert_equal '☹️', pdf_sentiment_emoji(2, system: :digital)
  end

  test 'pdf_sentiment_emoji returns correct emoji for facebook system' do
    assert_equal '😊', pdf_sentiment_emoji(1.5, system: :facebook)
    assert_equal '🙂', pdf_sentiment_emoji(0.8, system: :facebook)
    assert_equal '😐', pdf_sentiment_emoji(0.0, system: :facebook)
    assert_equal '☹️', pdf_sentiment_emoji(-0.8, system: :facebook)
    assert_equal '😠', pdf_sentiment_emoji(-1.8, system: :facebook)
  end

  test 'pdf_sentiment_emoji handles nil score' do
    assert_equal '❓', pdf_sentiment_emoji(nil, system: :digital)
  end

  test 'pdf_percentage calculates correctly' do
    assert_equal '50.0%', pdf_percentage(50, 100)
  end

  test 'pdf_percentage with custom precision' do
    assert_equal '33.33%', pdf_percentage(1, 3, precision: 2)
  end

  test 'pdf_percentage returns 0% when total is zero' do
    assert_equal '0%', pdf_percentage(50, 0)
  end

  test 'pdf_percentage returns 0% when total is nil' do
    assert_equal '0%', pdf_percentage(50, nil)
  end

  test 'pdf_metric_icon returns correct icons' do
    assert_equal '📝', pdf_metric_icon(:posts)
    assert_equal '🐦', pdf_metric_icon(:tweets)
    assert_equal '📰', pdf_metric_icon(:entries)
    assert_equal '📊', pdf_metric_icon(:interactions)
    assert_equal '👁️', pdf_metric_icon(:views)
    assert_equal '📈', pdf_metric_icon(:average)
    assert_equal '😊', pdf_metric_icon(:sentiment)
  end

  test 'pdf_metric_icon returns default for unknown type' do
    assert_equal '📌', pdf_metric_icon(:unknown_type)
  end

  test 'build_pdf_chart_config creates correct structure' do
    config = build_pdf_chart_config(
      title: 'Test Chart',
      data: { Date.today => 100 },
      type: :column_chart
    )

    assert_equal 'Test Chart', config[:title]
    assert_equal({ Date.today => 100 }, config[:data])
    assert_equal :column_chart, config[:type]
    assert config[:options].is_a?(Hash)
  end

  test 'build_pdf_chart_config includes default options' do
    config = build_pdf_chart_config(
      title: 'Test',
      data: {},
      type: :line_chart
    )

    assert_equal '.', config[:options][:thousands]
    assert_equal false, config[:options][:curve]
    assert_equal '200px', config[:options][:height]
  end

  test 'build_pdf_chart_config merges custom options' do
    config = build_pdf_chart_config(
      title: 'Test',
      data: {},
      type: :pie_chart,
      colors: ['#FF0000']
    )

    assert_equal ['#FF0000'], config[:options][:colors]
  end

  test 'build_pdf_chart_config includes data labels by default' do
    config = build_pdf_chart_config(
      title: 'Test',
      data: {},
      type: :column_chart
    )

    assert config[:options][:library][:plotOptions][:series][:dataLabels][:enabled]
  end
end


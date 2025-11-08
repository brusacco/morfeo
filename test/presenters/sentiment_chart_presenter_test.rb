# frozen_string_literal: true

require 'test_helper'

class SentimentChartPresenterTest < ActiveSupport::TestCase
  def setup
    @valid_options = {
      title: 'Test Title',
      icon: 'fa-test',
      icon_color: 'text-blue-600',
      chart_data_counts: { 'positive' => { '2024-01-01' => 10 } },
      chart_data_sums: { 'positive' => { '2024-01-01' => 100 } }
    }
  end

  # === Initialization Tests ===

  test 'initializes with required options' do
    presenter = SentimentChartPresenter.new(@valid_options)
    
    assert_equal 'Test Title', presenter.title
    assert_equal 'fa-test', presenter.icon
    assert_equal 'text-blue-600', presenter.icon_color
    assert_not_nil presenter.chart_data_counts
    assert_not_nil presenter.chart_data_sums
  end

  test 'uses default chart_id_prefix when not provided' do
    presenter = SentimentChartPresenter.new(@valid_options)
    assert_equal 'sentimentCountChart', presenter.count_chart_id
    assert_equal 'sentimentSumChart', presenter.sum_chart_id
  end

  test 'uses custom chart_id_prefix when provided' do
    options = @valid_options.merge(chart_id_prefix: 'custom')
    presenter = SentimentChartPresenter.new(options)
    
    assert_equal 'customCountChart', presenter.count_chart_id
    assert_equal 'customSumChart', presenter.sum_chart_id
  end

  # === Label Tests ===

  test 'count_label uses custom label when provided' do
    options = @valid_options.merge(count_label: 'Posts')
    presenter = SentimentChartPresenter.new(options)
    
    assert_equal 'Posts', presenter.count_label
  end

  test 'count_label uses I18n when not provided' do
    I18n.with_locale(:es) do
      presenter = SentimentChartPresenter.new(@valid_options)
      assert_equal I18n.t('sentiment.charts.count_label'), presenter.count_label
    end
  end

  test 'sum_label uses custom label when provided' do
    options = @valid_options.merge(sum_label: 'Likes')
    presenter = SentimentChartPresenter.new(options)
    
    assert_equal 'Likes', presenter.sum_label
  end

  test 'sum_label uses I18n when not provided' do
    I18n.with_locale(:es) do
      presenter = SentimentChartPresenter.new(@valid_options)
      assert_equal I18n.t('sentiment.charts.sum_label'), presenter.sum_label
    end
  end

  # === Stimulus Integration Tests ===

  test 'stimulus_enabled? returns false when controller_name not provided' do
    presenter = SentimentChartPresenter.new(@valid_options)
    assert_not presenter.stimulus_enabled?
  end

  test 'stimulus_enabled? returns false when topic_id not provided' do
    options = @valid_options.merge(controller_name: 'topics')
    presenter = SentimentChartPresenter.new(options)
    assert_not presenter.stimulus_enabled?
  end

  test 'stimulus_enabled? returns false when url_path not provided' do
    options = @valid_options.merge(controller_name: 'topics', topic_id: 1)
    presenter = SentimentChartPresenter.new(options)
    assert_not presenter.stimulus_enabled?
  end

  test 'stimulus_enabled? returns true when all required params provided' do
    options = @valid_options.merge(
      controller_name: 'topics',
      topic_id: 1,
      url_path: '/some/path'
    )
    presenter = SentimentChartPresenter.new(options)
    assert presenter.stimulus_enabled?
  end

  # === Stimulus Attributes Tests ===

  test 'count_chart_stimulus_attributes returns empty hash when Stimulus disabled' do
    presenter = SentimentChartPresenter.new(@valid_options)
    assert_equal({}, presenter.count_chart_stimulus_attributes)
  end

  test 'sum_chart_stimulus_attributes returns empty hash when Stimulus disabled' do
    presenter = SentimentChartPresenter.new(@valid_options)
    assert_equal({}, presenter.sum_chart_stimulus_attributes)
  end

  test 'count_chart_stimulus_attributes returns correct attributes when enabled' do
    options = @valid_options.merge(
      controller_name: 'topics',
      topic_id: 1,
      url_path: '/api/data',
      chart_id_prefix: 'test'
    )
    presenter = SentimentChartPresenter.new(options)
    attrs = presenter.count_chart_stimulus_attributes
    
    assert_equal 'topics', attrs[:'data-controller']
    assert_equal 'testCountChart', attrs[:'data-topics-id-value']
    assert_equal '/api/data', attrs[:'data-topics-url-value']
    assert_equal 1, attrs[:'data-topics-topic-id-value']
  end

  test 'sum_chart_stimulus_attributes returns correct attributes when enabled' do
    options = @valid_options.merge(
      controller_name: 'topics',
      topic_id: 1,
      url_path: '/api/data',
      chart_id_prefix: 'test'
    )
    presenter = SentimentChartPresenter.new(options)
    attrs = presenter.sum_chart_stimulus_attributes
    
    assert_equal 'topics', attrs[:'data-controller']
    assert_equal 'testSumChart', attrs[:'data-topics-id-value']
    assert_equal '/api/data', attrs[:'data-topics-url-value']
    assert_equal 1, attrs[:'data-topics-topic-id-value']
  end

  # === Chart ID Tests ===

  test 'count_chart_id is memoized' do
    presenter = SentimentChartPresenter.new(@valid_options)
    id1 = presenter.count_chart_id
    id2 = presenter.count_chart_id
    
    assert_same id1, id2
  end

  test 'sum_chart_id is memoized' do
    presenter = SentimentChartPresenter.new(@valid_options)
    id1 = presenter.sum_chart_id
    id2 = presenter.sum_chart_id
    
    assert_same id1, id2
  end
end


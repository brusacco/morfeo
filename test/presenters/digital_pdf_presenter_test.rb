# frozen_string_literal: true

require 'test_helper'

class DigitalPdfPresenterTest < ActiveSupport::TestCase
  def setup
    @data = {
      topic_data: {
        entries_count: 100,
        entries_total_sum: 5000,
        entries_polarity_counts: { 0 => 50, 1 => 30, 2 => 20 },
        entries_polarity_sums: { 0 => 2500, 1 => 1800, 2 => 700 },
        site_counts: { 'ABC.com.py' => 60, 'La Nación' => 40 },
        site_sums: { 'ABC.com.py' => 3000, 'La Nación' => 2000 }
      },
      chart_data: {
        chart_entries_counts: { Date.today => 50 },
        chart_entries_sums: { Date.today => 2500 }
      },
      tags_and_words: {
        tags_count: { 'Tag1' => 50, 'Tag2' => 50 },
        tags_interactions: { 'Tag1' => 2500, 'Tag2' => 2500 },
        word_occurrences: { 'word1' => 100, 'word2' => 80 },
        bigram_occurrences: { 'word1 word2' => 50 }
      },
      percentages: {
        positives: 30,
        neutrals: 50,
        negatives: 20
      }
    }
    
    @presenter = DigitalPdfPresenter.new(data: @data, days_range: 7)
  end

  test 'initializes with data' do
    assert_not_nil @presenter
    assert_equal @data, @presenter.data
  end

  test 'entries_count returns correct value' do
    assert_equal 100, @presenter.entries_count
  end

  test 'interactions_count returns correct value' do
    assert_equal 5000, @presenter.interactions_count
  end

  test 'estimated_reach calculates correctly' do
    # 5000 interactions * 3 = 15,000
    assert_equal 15_000, @presenter.estimated_reach
  end

  test 'average_interactions calculates correctly' do
    # 5000 / 100 = 50
    assert_equal 50, @presenter.average_interactions
  end

  test 'average_interactions returns 0 when entries_count is zero' do
    presenter = DigitalPdfPresenter.new(
      data: { topic_data: { entries_count: 0, entries_total_sum: 100 } }
    )
    assert_equal 0, presenter.average_interactions
  end

  test 'formatted_entries_count formats with delimiter' do
    assert_equal '100', @presenter.formatted_entries_count
  end

  test 'formatted_interactions_count formats with delimiter' do
    assert_equal '5.000', @presenter.formatted_interactions_count
  end

  test 'formatted_estimated_reach formats with delimiter' do
    assert_equal '15.000', @presenter.formatted_estimated_reach
  end

  test 'positive_sentiment returns correct data' do
    sentiment = @presenter.positive_sentiment
    assert_equal 30, sentiment[:count]
    assert_equal 1800, sentiment[:interactions]
  end

  test 'neutral_sentiment returns correct data' do
    sentiment = @presenter.neutral_sentiment
    assert_equal 50, sentiment[:count]
    assert_equal 2500, sentiment[:interactions]
  end

  test 'negative_sentiment returns correct data' do
    sentiment = @presenter.negative_sentiment
    assert_equal 20, sentiment[:count]
    assert_equal 700, sentiment[:interactions]
  end

  test 'has_sentiment_data? returns true when data exists' do
    assert @presenter.has_sentiment_data?
  end

  test 'has_sentiment_data? returns false when data missing' do
    presenter = DigitalPdfPresenter.new(data: { topic_data: {} })
    assert_not presenter.has_sentiment_data?
  end

  test 'has_site_data? returns true when data exists' do
    assert @presenter.has_site_data?
  end

  test 'has_site_data? returns false when data missing' do
    presenter = DigitalPdfPresenter.new(data: { topic_data: {} })
    assert_not presenter.has_site_data?
  end

  test 'has_tag_data? returns true when data exists' do
    assert @presenter.has_tag_data?
  end

  test 'has_word_data? returns true when data exists' do
    assert @presenter.has_word_data?
  end

  test 'has_bigram_data? returns true when data exists' do
    assert @presenter.has_bigram_data?
  end

  test 'site_counts returns correct data' do
    expected = { 'ABC.com.py' => 60, 'La Nación' => 40 }
    assert_equal expected, @presenter.site_counts
  end

  test 'site_sums returns correct data' do
    expected = { 'ABC.com.py' => 3000, 'La Nación' => 2000 }
    assert_equal expected, @presenter.site_sums
  end

  test 'kpi_metrics returns array of hashes' do
    metrics = @presenter.kpi_metrics
    assert_equal 4, metrics.length
    
    assert_equal 'Notas', metrics[0][:label]
    assert_equal '100', metrics[0][:value]
    assert_equal '📰', metrics[0][:icon]
    
    assert_equal 'Interacciones', metrics[1][:label]
    assert_equal 'Alcance Est.', metrics[2][:label]
    assert_equal 'Promedio', metrics[3][:label]
  end

  test 'reach_methodology returns explanation text' do
    methodology = @presenter.reach_methodology
    assert_includes methodology, '3x'
    assert_includes methodology, 'conservadora'
  end

  test 'chart data methods return correct values' do
    assert_equal({ Date.today => 50 }, @presenter.chart_entries_counts)
    assert_equal({ Date.today => 2500 }, @presenter.chart_entries_sums)
  end

  test 'handles nil data gracefully' do
    presenter = DigitalPdfPresenter.new(data: {})
    
    assert_equal 0, presenter.entries_count
    assert_equal 0, presenter.interactions_count
    assert_equal 0, presenter.estimated_reach
    assert_equal 0, presenter.average_interactions
    assert_equal({}, presenter.site_counts)
    assert_equal({}, presenter.word_occurrences)
  end

  test 'REACH_MULTIPLIER constant is defined' do
    assert_equal 3, DigitalPdfPresenter::REACH_MULTIPLIER
  end
end


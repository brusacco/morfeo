# frozen_string_literal: true

require 'test_helper'

class FacebookSentimentPresenterTest < ActiveSupport::TestCase
  # Test initialization
  test 'initializes with all sentiment data' do
    presenter = FacebookSentimentPresenter.new(
      sentiment_summary: { average_sentiment: 1.5 },
      sentiment_distribution: { positive: { percentage: 60 } },
      sentiment_over_time: { '2025-01-01' => 1.2 },
      reaction_breakdown: { love: 100 },
      top_positive_posts: [double('Post')],
      top_negative_posts: [double('Post')],
      controversial_posts: [double('Post'), double('Post')],
      sentiment_trend: { change_percent: 5.5, direction: 'up' },
      emotional_trends: { intensity: 0.8 }
    )

    assert_equal 1.5, presenter.average_sentiment
    assert_equal({ positive: { percentage: 60 } }, presenter.sentiment_distribution)
    assert_equal({ '2025-01-01' => 1.2 }, presenter.sentiment_over_time)
    assert_equal({ love: 100 }, presenter.reaction_breakdown)
    assert_equal 1, presenter.top_positive_posts.size
    assert_equal 1, presenter.top_negative_posts.size
    assert_equal 2, presenter.controversial_count
    assert_equal 5.5, presenter.trend_change_percent
    assert_equal 'up', presenter.trend_direction
  end

  test 'initializes with empty data' do
    presenter = FacebookSentimentPresenter.new

    refute presenter.has_data?
    assert_equal [], presenter.top_positive_posts
    assert_equal [], presenter.top_negative_posts
    assert_equal [], presenter.controversial_posts
    assert_equal 0, presenter.controversial_count
  end

  # Test has_data?
  test 'has_data? returns true when sentiment_summary present' do
    presenter = FacebookSentimentPresenter.new(sentiment_summary: { average_sentiment: 1.0 })
    assert presenter.has_data?
  end

  test 'has_data? returns false when sentiment_summary nil' do
    presenter = FacebookSentimentPresenter.new
    refute presenter.has_data?
  end

  # Test average_sentiment
  test 'average_sentiment returns value when data present' do
    presenter = FacebookSentimentPresenter.new(
      sentiment_summary: { average_sentiment: 0.75 }
    )
    assert_equal 0.75, presenter.average_sentiment
  end

  test 'average_sentiment returns nil when no data' do
    presenter = FacebookSentimentPresenter.new
    assert_nil presenter.average_sentiment
  end

  # Test statistical validity
  test 'has_validity_data? returns true when validity present' do
    presenter = FacebookSentimentPresenter.new(
      sentiment_summary: {
        statistical_validity: { overall_confidence: 0.85, total_reactions: 1000 }
      }
    )
    assert presenter.has_validity_data?
    assert_equal 0.85, presenter.overall_confidence
    assert_equal 1000, presenter.total_reactions
  end

  test 'has_validity_data? returns false when validity nil' do
    presenter = FacebookSentimentPresenter.new(sentiment_summary: {})
    refute presenter.has_validity_data?
    assert_equal 0.0, presenter.overall_confidence
    assert_equal 0, presenter.total_reactions
  end

  # Test high_confidence?
  test 'high_confidence? returns true when confidence > 0.7' do
    presenter = FacebookSentimentPresenter.new(
      sentiment_summary: { statistical_validity: { overall_confidence: 0.85 } }
    )
    assert presenter.high_confidence?
  end

  test 'high_confidence? returns false when confidence <= 0.7' do
    presenter = FacebookSentimentPresenter.new(
      sentiment_summary: { statistical_validity: { overall_confidence: 0.65 } }
    )
    refute presenter.high_confidence?
  end

  # Test trend methods
  test 'has_trend? returns true when trend data present' do
    presenter = FacebookSentimentPresenter.new(
      sentiment_trend: { change_percent: 5.5, direction: 'up', trend: 'al alza' }
    )
    assert presenter.has_trend?
    assert_equal 5.5, presenter.trend_change_percent
    assert_equal 'up', presenter.trend_direction
  end

  test 'has_trend? returns false when trend nil' do
    presenter = FacebookSentimentPresenter.new
    refute presenter.has_trend?
    assert_equal 0.0, presenter.trend_change_percent
    assert_equal 'stable', presenter.trend_direction
  end

  test 'trend_label returns localized value' do
    I18n.with_locale(:es) do
      presenter = FacebookSentimentPresenter.new(
        sentiment_trend: { direction: 'up' }
      )
      assert_equal I18n.t('sentiment.trend.up'), presenter.trend_label
    end
  end

  test 'trend_recent_score returns value when present' do
    presenter = FacebookSentimentPresenter.new(
      sentiment_trend: { recent_score: 1.2 }
    )
    assert_equal 1.2, presenter.trend_recent_score
  end

  # Test post presence checks
  test 'has_positive_posts? returns true when posts present' do
    presenter = FacebookSentimentPresenter.new(
      top_positive_posts: [double('Post')]
    )
    assert presenter.has_positive_posts?
  end

  test 'has_negative_posts? returns true when posts present' do
    presenter = FacebookSentimentPresenter.new(
      top_negative_posts: [double('Post')]
    )
    assert presenter.has_negative_posts?
  end

  test 'has_controversial_posts? returns true when posts present' do
    presenter = FacebookSentimentPresenter.new(
      controversial_posts: [double('Post'), double('Post')]
    )
    assert presenter.has_controversial_posts?
    assert_equal 2, presenter.controversial_count
  end

  # Test data presence checks
  test 'has_time_series? returns true when data present' do
    presenter = FacebookSentimentPresenter.new(
      sentiment_over_time: { '2025-01-01' => 1.0 }
    )
    assert presenter.has_time_series?
  end

  test 'has_distribution? returns true when data present' do
    presenter = FacebookSentimentPresenter.new(
      sentiment_distribution: { positive: { count: 10 } }
    )
    assert presenter.has_distribution?
  end

  test 'has_reaction_breakdown? returns true when data present' do
    presenter = FacebookSentimentPresenter.new(
      reaction_breakdown: { love: 100, like: 50 }
    )
    assert presenter.has_reaction_breakdown?
  end

  # Test formatted_score
  test 'formatted_score formats with default precision' do
    presenter = FacebookSentimentPresenter.new
    assert_equal '1.23', presenter.formatted_score(1.2345)
  end

  test 'formatted_score formats with custom precision' do
    presenter = FacebookSentimentPresenter.new
    assert_equal '1.2', presenter.formatted_score(1.2345, precision: 1)
  end

  test 'formatted_score handles nil' do
    presenter = FacebookSentimentPresenter.new
    assert_equal '0.0', presenter.formatted_score(nil)
  end

  # Test chart data methods
  test 'sentiment_time_series_data returns data when present' do
    data = { '2025-01-01' => 1.0, '2025-01-02' => 1.2 }
    presenter = FacebookSentimentPresenter.new(sentiment_over_time: data)
    assert_equal data, presenter.sentiment_time_series_data
  end

  test 'sentiment_time_series_data returns empty hash when no data' do
    presenter = FacebookSentimentPresenter.new
    assert_equal({}, presenter.sentiment_time_series_data)
  end

  test 'sentiment_distribution_data transforms for Chartkick' do
    distribution = {
      very_positive: { percentage: 30 },
      positive: { percentage: 20 },
      neutral: { percentage: 30 },
      negative: { percentage: 15 },
      very_negative: { percentage: 5 }
    }
    presenter = FacebookSentimentPresenter.new(sentiment_distribution: distribution)
    
    result = presenter.sentiment_distribution_data
    assert_equal 5, result.size
    assert_instance_of Array, result.first
    assert_equal 2, result.first.size
  end

  test 'reaction_breakdown_data transforms for Chartkick' do
    breakdown = { love: 100, like: 50, haha: 30 }
    presenter = FacebookSentimentPresenter.new(reaction_breakdown: breakdown)
    
    result = presenter.reaction_breakdown_data
    assert result.is_a?(Hash)
    refute result.empty?
  end

  # Test configuration
  test 'config returns correct values' do
    presenter = FacebookSentimentPresenter.new
    config = presenter.config

    assert_equal(-2.0, config[:min_score])
    assert_equal 2.0, config[:max_score]
    assert_equal 4.0, config[:score_range]
    assert_equal 0.7, config[:high_confidence_threshold]
    assert config[:chart_colors].is_a?(Hash)
  end

  test 'chart_color returns correct color' do
    presenter = FacebookSentimentPresenter.new
    
    assert_equal '#8b5cf6', presenter.chart_color(:primary)
    assert_equal '#10b981', presenter.chart_color(:positive)
    assert_equal '#ef4444', presenter.chart_color(:negative)
    assert_equal '#6b7280', presenter.chart_color(:nonexistent)
  end

  private

  # Simple double helper for tests
  def double(name)
    Object.new
  end
end


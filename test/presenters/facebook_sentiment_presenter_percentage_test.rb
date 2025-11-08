# frozen_string_literal: true

require 'test_helper'

class FacebookSentimentPresenterPercentageTest < ActiveSupport::TestCase
  def setup
    @sentiment_distribution = {
      very_positive: { count: 10, percentage: 10.0 },
      positive: { count: 50, percentage: 50.0 },
      neutral: { count: 30, percentage: 30.0 },
      negative: { count: 8, percentage: 8.0 },
      very_negative: { count: 2, percentage: 2.0 }
    }

    @presenter = FacebookSentimentPresenter.new(
      sentiment_distribution: @sentiment_distribution
    )
  end

  test 'positive_percentage calculates correctly' do
    # (10 + 50) / 100 = 60.0%
    assert_equal 60.0, @presenter.positive_percentage
  end

  test 'neutral_percentage calculates correctly' do
    # 30 / 100 = 30.0%
    assert_equal 30.0, @presenter.neutral_percentage
  end

  test 'negative_percentage calculates correctly' do
    # (8 + 2) / 100 = 10.0%
    assert_equal 10.0, @presenter.negative_percentage
  end

  test 'percentages return 0 when no distribution data' do
    presenter = FacebookSentimentPresenter.new(sentiment_distribution: nil)
    
    assert_equal 0.0, presenter.positive_percentage
    assert_equal 0.0, presenter.neutral_percentage
    assert_equal 0.0, presenter.negative_percentage
  end

  test 'percentages return 0 when total is zero' do
    empty_distribution = {
      very_positive: { count: 0, percentage: 0.0 },
      positive: { count: 0, percentage: 0.0 },
      neutral: { count: 0, percentage: 0.0 },
      negative: { count: 0, percentage: 0.0 },
      very_negative: { count: 0, percentage: 0.0 }
    }
    
    presenter = FacebookSentimentPresenter.new(sentiment_distribution: empty_distribution)
    
    assert_equal 0.0, presenter.positive_percentage
    assert_equal 0.0, presenter.neutral_percentage
    assert_equal 0.0, presenter.negative_percentage
  end

  test 'percentages are rounded to 1 decimal place' do
    distribution = {
      very_positive: { count: 1, percentage: 0.0 },
      positive: { count: 2, percentage: 0.0 },
      neutral: { count: 3, percentage: 0.0 },
      negative: { count: 1, percentage: 0.0 },
      very_negative: { count: 0, percentage: 0.0 }
    }
    
    presenter = FacebookSentimentPresenter.new(sentiment_distribution: distribution)
    
    # 3 / 7 = 42.857... should round to 42.9
    assert_in_delta 42.9, presenter.positive_percentage, 0.1
    assert_in_delta 42.9, presenter.neutral_percentage, 0.1
    assert_in_delta 14.3, presenter.negative_percentage, 0.1
  end

  test 'percentages sum to approximately 100%' do
    positive = @presenter.positive_percentage
    neutral = @presenter.neutral_percentage
    negative = @presenter.negative_percentage
    
    total = positive + neutral + negative
    
    # Should be very close to 100 (allowing for rounding)
    assert_in_delta 100.0, total, 0.5
  end

  test 'has_distribution? returns true when distribution present' do
    assert @presenter.has_distribution?
  end

  test 'has_distribution? returns false when distribution nil' do
    presenter = FacebookSentimentPresenter.new(sentiment_distribution: nil)
    assert_not presenter.has_distribution?
  end
end


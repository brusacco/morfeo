# frozen_string_literal: true

require 'rails_helper'

RSpec.describe FacebookSentimentPresenter do
  subject(:presenter) { described_class.new(sentiment_distribution: sentiment_distribution) }

  let(:sentiment_distribution) do
    {
      very_positive: { count: 10, percentage: 10.0 },
      positive: { count: 50, percentage: 50.0 },
      neutral: { count: 30, percentage: 30.0 },
      negative: { count: 8, percentage: 8.0 },
      very_negative: { count: 2, percentage: 2.0 }
    }
  end

  it 'calculates percentages' do
    expect(presenter.positive_percentage).to eq(60.0)
    expect(presenter.neutral_percentage).to eq(30.0)
    expect(presenter.negative_percentage).to eq(10.0)
    expect(presenter.has_distribution?).to be(true)
  end

  it 'returns zero percentages without data' do
    empty = described_class.new(sentiment_distribution: nil)

    expect(empty.positive_percentage).to eq(0.0)
    expect(empty.neutral_percentage).to eq(0.0)
    expect(empty.negative_percentage).to eq(0.0)
    expect(empty.has_distribution?).to be(false)
  end
end
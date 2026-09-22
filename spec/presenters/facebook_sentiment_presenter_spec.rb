# frozen_string_literal: true

require 'rails_helper'

RSpec.describe FacebookSentimentPresenter do
  it 'exposes the presenter data and computed values' do
    presenter = described_class.new(
      sentiment_summary: { average_sentiment: 1.5 },
      sentiment_distribution: { positive: { percentage: 60 } },
      sentiment_over_time: { '2025-01-01' => 1.2 },
      reaction_breakdown: { love: 100 },
      top_positive_posts: [Object.new],
      top_negative_posts: [Object.new],
      controversial_posts: [Object.new, Object.new],
      sentiment_trend: { change_percent: 5.5, direction: 'up' },
      emotional_trends: { intensity: 0.8 }
    )

    expect(presenter.average_sentiment).to eq(1.5)
    expect(presenter.sentiment_distribution).to eq({ positive: { percentage: 60 } })
    expect(presenter.sentiment_over_time).to eq({ '2025-01-01' => 1.2 })
    expect(presenter.reaction_breakdown).to eq({ love: 100 })
    expect(presenter.top_positive_posts.size).to eq(1)
    expect(presenter.top_negative_posts.size).to eq(1)
    expect(presenter.controversial_count).to eq(2)
    expect(presenter.trend_change_percent).to eq(5.5)
    expect(presenter.trend_direction).to eq('up')
  end

  it 'handles empty data and formatting helpers' do
    presenter = described_class.new

    expect(presenter.has_data?).to be(false)
    expect(presenter.top_positive_posts).to eq([])
    expect(presenter.top_negative_posts).to eq([])
    expect(presenter.controversial_posts).to eq([])
    expect(presenter.controversial_count).to eq(0)
    expect(presenter.average_sentiment).to be_nil
    expect(presenter.has_validity_data?).to be(false)
    expect(presenter.overall_confidence).to eq(0.0)
    expect(presenter.total_reactions).to eq(0)
    expect(presenter.has_trend?).to be(false)
    expect(presenter.trend_direction).to eq('stable')
    expect(presenter.formatted_score(1.2345)).to eq('1.23')
    expect(presenter.formatted_score(1.2345, precision: 1)).to eq('1.2')
    expect(presenter.formatted_score(nil)).to eq('0.0')
  end

  it 'builds chart data and config' do
    presenter = described_class.new(
      sentiment_distribution: {
        very_positive: { percentage: 30 },
        positive: { percentage: 20 },
        neutral: { percentage: 30 },
        negative: { percentage: 15 },
        very_negative: { percentage: 5 }
      },
      reaction_breakdown: { love: 100, like: 50, haha: 30 }
    )

    expect(presenter.sentiment_distribution_data.length).to eq(5)
    expect(presenter.reaction_breakdown_data).to be_a(Hash)
    expect(presenter.config[:min_score]).to eq(-2.0)
    expect(presenter.chart_color(:primary)).to eq('#8b5cf6')
  end
end
# frozen_string_literal: true

require 'rails_helper'

RSpec.describe DigitalPdfPresenter do
  subject(:presenter) { described_class.new(data: data, days_range: 7) }

  let(:data) do
    {
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
  end

  it 'exposes the expected counts and metrics' do
    expect(presenter.entries_count).to eq(100)
    expect(presenter.interactions_count).to eq(5000)
    expect(presenter.estimated_reach).to eq(15_000)
    expect(presenter.average_interactions).to eq(50)
    expect(presenter.formatted_entries_count).to eq('100')
    expect(presenter.formatted_interactions_count).to eq('5.000')
    expect(presenter.formatted_estimated_reach).to eq('15.000')
  end

  it 'exposes sentiment and chart data' do
    expect(presenter.positive_sentiment).to eq(count: 30, interactions: 1800)
    expect(presenter.neutral_sentiment).to eq(count: 50, interactions: 2500)
    expect(presenter.negative_sentiment).to eq(count: 20, interactions: 700)
    expect(presenter.has_sentiment_data?).to be(true)
    expect(presenter.has_site_data?).to be(true)
    expect(presenter.has_tag_data?).to be(true)
    expect(presenter.has_word_data?).to be(true)
    expect(presenter.has_bigram_data?).to be(true)
    expect(presenter.chart_entries_counts).to eq(Date.today => 50)
    expect(presenter.chart_entries_sums).to eq(Date.today => 2500)
    expect(presenter.site_counts).to eq('ABC.com.py' => 60, 'La Nación' => 40)
    expect(presenter.site_sums).to eq('ABC.com.py' => 3000, 'La Nación' => 2000)
  end

  it 'returns the KPI metrics and methodology text' do
    metrics = presenter.kpi_metrics

    expect(metrics.length).to eq(4)
    expect(metrics[0][:label]).to eq('Notas')
    expect(metrics[0][:value]).to eq('100')
    expect(metrics[0][:icon]).to eq('📰')
    expect(presenter.reach_methodology).to include('3x')
    expect(presenter.reach_methodology).to include('conservadora')
  end

  it 'handles empty data' do
    empty = described_class.new(data: {})

    expect(empty.entries_count).to eq(0)
    expect(empty.interactions_count).to eq(0)
    expect(empty.estimated_reach).to eq(0)
    expect(empty.average_interactions).to eq(0)
    expect(empty.site_counts).to eq({})
    expect(empty.word_occurrences).to eq({})
  end

  it 'defines the reach multiplier constant' do
    expect(described_class::REACH_MULTIPLIER).to eq(3)
  end
end
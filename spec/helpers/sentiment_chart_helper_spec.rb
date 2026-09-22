# frozen_string_literal: true

require 'rails_helper'

RSpec.describe SentimentChartHelper, type: :helper do
  it 'exposes the frozen sentiment palette' do
    expect(helper.sentiment_colors).to eq(['#10B981', '#9CA3AF', '#EF4444'])
    expect(SentimentChartHelper::SENTIMENT_COLORS).to be_frozen
    expect(SentimentChartHelper::SENTIMENT_COLOR_ARRAY).to be_frozen
    expect(SentimentChartHelper::SENTIMENT_KEYS).to be_frozen
  end

  it 'builds chart config with overrides' do
    config = helper.sentiment_line_chart_config(height: 400, line_width: 5, marker_radius: 6, legend: false)

    expect(config[:chart][:height]).to eq(400)
    expect(config[:plotOptions][:series][:lineWidth]).to eq(5)
    expect(config[:plotOptions][:series][:marker][:radius]).to eq(6)
    expect(config[:legend][:enabled]).to be(false)
  end

  it 'builds legend data' do
    data = helper.sentiment_legend_data

    expect(data).to be_an(Array)
    expect(data.length).to eq(3)
    expect(data.map { |item| item[:key] }).to include(:positive, :neutral, :negative)
  end

  it 'builds legacy html legend' do
    html = helper.sentiment_legend_html

    expect(html).to match(/Positivo/)
    expect(html).to match(/Neutro/)
    expect(html).to match(/Negativo/)
  end
end
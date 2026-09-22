# frozen_string_literal: true

require 'rails_helper'

RSpec.describe PdfHelper, type: :helper do
  it 'formats numbers' do
    expect(helper.pdf_format_number(nil)).to eq('0')
    expect(helper.pdf_format_number(1_234_567)).to eq('1.234.567')
  end

  it 'builds date ranges' do
    expect(helper.pdf_date_range(days_range: 7)).to include('Últimos 7 días')
    expect(helper.pdf_date_range(start_date: Date.new(2025, 1, 1), end_date: Date.new(2025, 1, 7))).to eq('01/01/2025 - 07/01/2025')
    expect(helper.pdf_date_range).to eq('Período analizado')
  end

  it 'maps sentiment emoji values' do
    expect(helper.pdf_sentiment_emoji(1, system: :digital)).to eq('😊')
    expect(helper.pdf_sentiment_emoji(-1.8, system: :facebook)).to eq('😠')
    expect(helper.pdf_sentiment_emoji(nil, system: :digital)).to eq('❓')
  end

  it 'formats percentages' do
    expect(helper.pdf_percentage(50, 100)).to eq('50.0%')
    expect(helper.pdf_percentage(1, 3, precision: 2)).to eq('33.33%')
    expect(helper.pdf_percentage(50, 0)).to eq('0%')
  end

  it 'returns metric icons' do
    expect(helper.pdf_metric_icon(:entries)).to eq('📰')
    expect(helper.pdf_metric_icon(:unknown_type)).to eq('📌')
  end

  it 'builds a PDF chart config' do
    config = helper.build_pdf_chart_config(title: 'Test Chart', data: { Date.today => 100 }, type: :column_chart)

    expect(config[:title]).to eq('Test Chart')
    expect(config[:data]).to eq({ Date.today => 100 })
    expect(config[:type]).to eq(:column_chart)
    expect(config[:options]).to be_a(Hash)
  end

  it 'returns KPI metrics and methodology text' do
    presenter = instance_double(
      DigitalPdfPresenter,
      formatted_entries_count: '100',
      formatted_interactions_count: '5.000',
      formatted_estimated_reach: '15.000',
      formatted_average_interactions: '50',
      instance_variable_get: nil
    )

    allow(presenter).to receive(:instance_variable_get).and_return(nil)

    expect(helper.pdf_metric_icon(:posts)).to eq('📝')
    expect(helper.pdf_date_range).to eq('Período analizado')
  end
end
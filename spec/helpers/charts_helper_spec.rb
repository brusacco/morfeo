# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ChartsHelper, type: :helper do
  before do
    allow(helper).to receive(:render).and_return('')
  end

  it 'returns the expected chart colors' do
    expect(helper.chart_color(:primary)).to eq('#3B82F6')
    expect(helper.chart_color(:unknown_color)).to eq('#3B82F6')
  end

  it 'returns multiple colors' do
    expect(helper.chart_colors(:success, :danger)).to eq(['#10B981', '#EF4444'])
  end

  it 'builds the sentiment chart config' do
    config = helper.sentiment_chart_config

    expect(config[:colors]).to eq(['#10B981', '#9CA3AF', '#EF4444'])
    expect(config[:plotOptions][:series][:stacking]).to eq('normal')
    expect(config[:plotOptions][:series][:dataLabels][:enabled]).to be(false)
  end

  it 'builds clickable chart options' do
    options = {
      chart_id: 'testChart',
      url: '/test/path',
      topic_id: 123,
      label: 'Test Label',
      color: :primary,
      xtitle: 'X Axis',
      ytitle: 'Y Axis'
    }

    result = helper.send(:build_chart_options, options)

    expect(result[:id]).to eq('testChart')
    expect(result[:xtitle]).to eq('X Axis')
    expect(result[:ytitle]).to eq('Y Axis')
    expect(result[:adapter]).to eq('highcharts')
    expect(result[:thousands]).to eq('.')
    expect(result[:colors]).to eq(['#3B82F6'])
  end

  it 'builds the library config' do
    config = helper.send(:build_library_config, 'Publicaciones')

    expect(config[:tooltip][:pointFormat]).to eq('<b>{point.y}</b> Publicaciones')
  end

  it 'builds wrapper options' do
    options = {
      url: '/test/path',
      chart_id: 'testChart',
      topic_id: 123,
      clickable: true
    }

    result = helper.send(:build_wrapper_options, options)

    expect(result[:class]).to eq('w-full overflow-hidden')
    expect(result[:data][:controller]).to eq('topics')
    expect(result[:data][:topics_id_value]).to eq('testChart')
    expect(result[:data][:topics_url_value]).to eq('/test/path')
    expect(result[:data][:topics_topic_id_value]).to eq(123)
    expect(result[:data][:topics_title_value]).to eq(false)
  end

  it 'renders a clickable column chart' do
    html = helper.render_column_chart(
      { '2024-01-01' => 10, '2024-01-02' => 20 },
      chart_id: 'testChart',
      url: '/test/path',
      topic_id: 123,
      label: 'Test',
      color: :primary,
      xtitle: 'Date',
      ytitle: 'Count'
    )

    expect(html).to include('w-full overflow-hidden')
    expect(html).to include('data-controller="topics"')
    expect(html).to include('data-topics-id-value="testChart"')
  end

  it 'renders an area chart' do
    html = helper.render_area_chart(
      { '2024-01-01' => 10, '2024-01-02' => 20 },
      chart_id: 'areaChart',
      url: '/test/path',
      topic_id: 123,
      label: 'Test',
      stacked: true
    )

    expect(html).to include('w-full overflow-hidden')
    expect(html).not_to be_nil
  end

  it 'renders a pie chart' do
    html = helper.render_pie_chart({ 'Category A' => 30, 'Category B' => 70 }, donut: true, suffix: '%')

    expect(html).not_to include('data-controller="topics"')
    expect(html).not_to be_nil
  end
end
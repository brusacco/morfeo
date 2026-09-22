# frozen_string_literal: true

require 'rails_helper'

RSpec.describe SentimentChartPresenter do
  let(:options) do
    {
      title: 'Test Title',
      icon: 'fa-test',
      icon_color: 'text-blue-600',
      chart_data_counts: { 'positive' => { '2024-01-01' => 10 } },
      chart_data_sums: { 'positive' => { '2024-01-01' => 100 } }
    }
  end

  it 'initializes and exposes chart metadata' do
    presenter = described_class.new(options)

    expect(presenter.title).to eq('Test Title')
    expect(presenter.icon).to eq('fa-test')
    expect(presenter.icon_color).to eq('text-blue-600')
    expect(presenter.chart_data_counts).not_to be_nil
    expect(presenter.chart_data_sums).not_to be_nil
    expect(presenter.count_chart_id).to eq('sentimentCountChart')
    expect(presenter.sum_chart_id).to eq('sentimentSumChart')
  end

  it 'uses custom labels and stimulus attributes' do
    presenter = described_class.new(options.merge(count_label: 'Posts', sum_label: 'Likes'))

    expect(presenter.count_label).to eq('Posts')
    expect(presenter.sum_label).to eq('Likes')
    expect(presenter.stimulus_enabled?).to be(false)
    expect(presenter.count_chart_stimulus_attributes).to eq({})
    expect(presenter.sum_chart_stimulus_attributes).to eq({})
  end

  it 'supports stimulus integration when configured' do
    presenter = described_class.new(
      options.merge(
        controller_name: 'topics',
        topic_id: 1,
        url_path: '/api/data',
        chart_id_prefix: 'test'
      )
    )

    expect(presenter.stimulus_enabled?).to be(true)
    expect(presenter.count_chart_stimulus_attributes[:'data-controller']).to eq('topics')
    expect(presenter.count_chart_stimulus_attributes[:'data-topics-id-value']).to eq('testCountChart')
    expect(presenter.sum_chart_stimulus_attributes[:'data-topics-id-value']).to eq('testSumChart')
    expect(presenter.count_chart_id).to be(presenter.count_chart_id)
    expect(presenter.sum_chart_id).to be(presenter.sum_chart_id)
  end
end

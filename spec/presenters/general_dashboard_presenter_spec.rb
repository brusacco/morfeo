# frozen_string_literal: true

require 'rails_helper'

RSpec.describe GeneralDashboardPresenter do
  subject(:presenter) { described_class.new(data: data) }

  let(:data) do
    {
      executive_summary: {
        total_mentions: 100,
        total_interactions: 200,
        total_reach: 300,
        average_sentiment: 0
      }
    }
  end

  it 'labels the reach KPI without implying that Instagram video views are included' do
    reach_metric = presenter.kpi_metrics.find { |metric| metric[:value] == presenter.formatted_total_reach }

    expect(reach_metric).to include(label: 'Alcance potencial total')
  end
end

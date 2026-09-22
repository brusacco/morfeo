# frozen_string_literal: true

require 'rails_helper'

RSpec.describe FacebookDashboardServices::PdfService do
  let(:topic) { double('topic', id: 7) }
  let(:service) { described_class.new(topic: topic) }

  before do
    allow(described_class).to receive(:new).and_return(service)
  end

  it 'returns the PDF payload' do
    allow(service).to receive_messages(
      load_topic_data: { topic: 'data' },
      load_chart_data: { chart: 'data' },
      load_sentiment_analysis: { sentiment: 'data' },
      calculate_pdf_percentages: { percentage: 100 }
    )

    expect(described_class.call(topic: topic)).to eq(
      topic_data: { topic: 'data' },
      chart_data: { chart: 'data' },
      sentiment_analysis: { sentiment: 'data' },
      percentages: { percentage: 100 }
    )
  end
end

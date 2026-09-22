# frozen_string_literal: true

require 'rails_helper'

RSpec.describe DigitalDashboardServices::PdfService do
  let(:tags_relation) { double('tags_relation', pluck: %w[alpha beta]) }
  let(:topic) { double('topic', id: 7, tags: tags_relation) }
  let(:service) { described_class.new(topic: topic) }

  before do
    allow(described_class).to receive(:new).and_return(service)
  end

  it 'returns the PDF payload' do
    allow(service).to receive_messages(
      topic_data: { topic: 'data' },
      load_chart_data: { chart: 'data' },
      load_tags_and_words: { words: %w[a b] },
      calculate_pdf_percentages: { percentage: 100 }
    )

    expect(described_class.call(topic: topic)).to eq(
      topic_data: { topic: 'data' },
      chart_data: { chart: 'data' },
      tags_and_words: { words: %w[a b] },
      percentages: { percentage: 100 }
    )
  end
end
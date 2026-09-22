# frozen_string_literal: true

require 'rails_helper'

RSpec.describe TagPdfServices::PdfService do
  let(:tag) { double('tag', id: 7, name: 'Politics') }
  let(:service) { described_class.new(tag: tag) }

  before do
    allow(described_class).to receive(:new).and_return(service)
  end

  it 'returns the PDF payload' do
    allow(service).to receive_messages(
      tag_data: { tag: 'data' },
      load_chart_data: { chart: 'data' },
      load_tags_and_words: { words: %w[a b] },
      calculate_pdf_percentages: { percentage: 100 }
    )

    expect(described_class.call(tag: tag)).to eq(
      tag_data: { tag: 'data' },
      chart_data: { chart: 'data' },
      tags_and_words: { words: %w[a b] },
      percentages: { percentage: 100 }
    )
  end
end
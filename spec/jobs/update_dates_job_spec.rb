# frozen_string_literal: true

require 'rails_helper'

RSpec.describe UpdateDatesJob, type: :job do
  it 'updates the entry with the extracted date data' do
    entry = instance_double(Entry, url: 'https://example.test/article', update!: true)
    document = double('Document')
    extraction = instance_double('ExtractionResult', success?: true, data: { published_at: Date.current })

    allow(Entry).to receive(:find).with(1).and_return(entry)
    allow(URI).to receive(:parse).and_return(double(open: '<html></html>'))
    allow(Nokogiri).to receive(:HTML).and_return(document)
    allow(WebExtractorServices::ExtractDate).to receive(:call).with(document).and_return(extraction)

    described_class.perform_now(1)

    expect(entry).to have_received(:update!).with(published_at: Date.current)
  end
end

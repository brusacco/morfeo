# frozen_string_literal: true

require 'rails_helper'

RSpec.describe WebExtractorServices::ExtractDate, type: :service do
  let(:result) { described_class.call(doc) }

  context 'with Open Graph published_time' do
    let(:doc) do
      Nokogiri::HTML('<html><head><meta property="article:published_time" content="2026-09-24T15:00:00-03:00"></head></html>')
    end

    it 'extracts and parses the date' do
      expect(result).to be_success
      expect(result.data[:published_at]).to be_a(Time)
    end
  end

  context 'with Open Graph modified_time (fallback)' do
    let(:doc) do
      Nokogiri::HTML('<html><head><meta property="article:modified_time" content="2026-09-24T15:00:00Z"></head></html>')
    end

    it 'uses modified_time when published_time is absent' do
      expect(result).to be_success
      expect(result.data[:published_at]).to be_a(Time)
    end
  end

  context 'with priority: published_time takes precedence' do
    let(:doc) do
      html = '<html><head>'
      html += '<meta property="article:published_time" content="2026-09-20T10:00:00Z">'
      html += '<meta property="article:modified_time" content="2026-09-24T15:00:00Z">'
      html += '</head></html>'
      Nokogiri::HTML(html)
    end

    it 'uses published_time over modified_time' do
      expect(result).to be_success
      expect(result.data[:published_at].to_date).to eq(Date.new(2026, 9, 20))
    end
  end

  context 'with JSON-LD datePublished' do
    let(:doc) do
      Nokogiri::HTML('<html><body><script type="application/ld+json">{"@context":"http://schema.org","datePublished":"2026-09-24"}</script></body></html>')
    end

    it 'extracts the date from JSON-LD' do
      expect(result).to be_success
      expect(result.data[:published_at]).to be_a(Time)
    end
  end

  context 'with malformed JSON-LD' do
    let(:doc) do
      Nokogiri::HTML('<html><body><script type="application/ld+json">{"invalid json"</script></body></html>')
    end

    it 'handles JSON parsing errors gracefully' do
      expect(result.success?).to be false
      expect(result.error).to eq('Fecha no encontrada')
    end
  end

  context 'with JSON-LD missing datePublished' do
    let(:doc) do
      Nokogiri::HTML('<html><body><script type="application/ld+json">{"@context":"http://schema.org","name":"Test"}</script></body></html>')
    end

    it 'falls through when datePublished is absent' do
      expect(result.success?).to be false
      expect(result.error).to eq('Fecha no encontrada')
    end
  end

  context 'with .entry-date datetime attribute' do
    let(:doc) do
      Nokogiri::HTML('<html><body><time class="entry-date" datetime="2026-09-24T15:00:07-03:00">24/09/2026</time></body></html>')
    end

    it 'extracts the datetime attribute' do
      expect(result).to be_success
      expect(result.data[:published_at]).to be_a(Time)
    end
  end

  context 'with .modern-article-meta' do
    let(:doc) do
      Nokogiri::HTML('<html><body><div class="modern-article-meta"><span>🕒 HACE 5 H</span><span>📅 24/09/2026 10:59</span></div></body></html>')
    end

    it 'extracts the date from second span' do
      expect(result).to be_success
      expect(result.data[:published_at]).to be_a(Time)
    end
  end

  context 'with Spanish date text' do
    let(:doc) do
      Nokogiri::HTML('<html><body><span class="date">24 de septiembre de 2026</span></body></html>')
    end

    it 'translates and parses Spanish date' do
      expect(result).to be_success
      expect(result.data[:published_at]).to be_a(Time)
    end
  end

  context 'with "ayer" (yesterday)' do
    let(:doc) do
      Nokogiri::HTML('<html><body><span class="date">Ayer</span></body></html>')
    end

    it 'translates ayer to yesterday' do
      expect(result).to be_success
      expect(result.data[:published_at]).to be_a(Time)
    end
  end

  context 'with "hoy" (today)' do
    let(:doc) do
      Nokogiri::HTML('<html><body><span class="date">Hoy</span></body></html>')
    end

    it 'translates hoy to today' do
      expect(result).to be_success
      expect(result.data[:published_at]).to be_a(Time)
    end
  end

  context 'with emoji prefix' do
    let(:doc) do
      Nokogiri::HTML('<html><body><span class="date">📅 24/09/2026</span></body></html>')
    end

    it 'strips emoji and parses date' do
      expect(result).to be_success
      expect(result.data[:published_at]).to be_a(Time)
    end
  end

  context 'with relative time ("hace X horas")' do
    let(:doc) do
      Nokogiri::HTML('<html><body><span class="date">Hace 3 horas</span></body></html>')
    end

    it 'parses relative time' do
      expect(result).to be_success
      expect(result.data[:published_at]).to be_a(Time)
    end
  end

  context 'with relative time ("hace X días")' do
    let(:doc) do
      Nokogiri::HTML('<html><body><span class="date">Hace 5 días</span></body></html>')
    end

    it 'parses relative days' do
      expect(result).to be_success
      expect(result.data[:published_at]).to be_a(Time)
    end
  end

  context 'with .time date selector' do
    let(:doc) do
      Nokogiri::HTML('<html><body><span class="time date">24/09/2026</span></body></html>')
    end

    it 'extracts date from .time.date selector' do
      expect(result).to be_success
      expect(result.data[:published_at]).to be_a(Time)
    end
  end

  context 'with <time> datetime attribute' do
    let(:doc) do
      Nokogiri::HTML('<html><body><time datetime="2026-09-24T14:00:00Z">Sep 24</time></body></html>')
    end

    it 'uses the datetime attribute' do
      expect(result).to be_success
      expect(result.data[:published_at]).to be_a(Time)
    end
  end

  context 'with <time class="article-header__date">' do
    let(:doc) do
      Nokogiri::HTML('<html><body><time class="article-header__date" datetime="2026-07-16T20:19:00Z">16 de julio de 2026 - 17:19</time></body></html>')
    end

    it 'uses the datetime attribute regardless of class' do
      expect(result).to be_success
      expect(result.data[:published_at]).to be_a(Time)
      expect(result.data[:published_at].to_date).to eq(Date.new(2026, 7, 16))
    end
  end

  context 'with date at boundary (exactly 10 years ago)' do
    before do
      allow(Time).to receive(:now).and_return(Time.new(2026, 9, 24, 12, 0, 0, '-03:00'))
    end

    let(:doc) do
      Nokogiri::HTML('<html><body><span class="date">24/09/2016</span></body></html>')
    end

    it 'accepts exactly 10 years ago' do
      expect(result).to be_success
    end
  end

  context 'with invalid date format' do
    let(:doc) do
      Nokogiri::HTML('<html><body><span class="date">not a date</span></body></html>')
    end

    it 'returns error when Chronic fails to parse' do
      # "not a date" gets parsed by Chronic to some default date which may be out of range
      expect(result.success?).to be false
    end
  end

  context 'with no date found' do
    let(:doc) do
      Nokogiri::HTML('<html><body>No date here</body></html>')
    end

    it 'returns error' do
      expect(result.success?).to be false
      expect(result.error).to eq('Fecha no encontrada')
    end
  end

  context 'with date out of range (too old)' do
    let(:doc) do
      Nokogiri::HTML('<html><body><span class="date">24/09/1990</span></body></html>')
    end

    it 'returns out of range error' do
      expect(result.success?).to be false
      expect(result.error).to eq('Fecha fuera de rango')
    end
  end

  context 'with date out of range (too far in future)' do
    let(:doc) do
      Nokogiri::HTML('<html><body><span class="date">24/09/2100</span></body></html>')
    end

    it 'returns out of range error' do
      expect(result.success?).to be false
      expect(result.error).to eq('Fecha fuera de rango')
    end
  end

  context 'with timezone conversion' do
    let(:doc) do
      Nokogiri::HTML('<html><head><meta property="article:published_time" content="2026-09-24T18:00:00Z"></head></html>')
    end

    it 'converts to America/Asuncion' do
      expect(result).to be_success
      expect(result.data[:published_at].utc_offset).to eq(-10_800) # UTC-3
    end
  end
end

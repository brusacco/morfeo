# frozen_string_literal: true

require 'rails_helper'

RSpec.shared_examples 'social text analysis' do
  it 'builds word and bigram occurrences in one scan' do
    posts = [double(words: %w[alpha beta]), double(words: %w[alpha beta])]
    scope = double('scope')
    allow(scope).to receive(:reorder).with(posted_at: :desc).and_return(scope)
    allow(scope).to receive(:limit).and_return(scope)
    allow(scope).to receive(:select).and_return(scope)
    expect(scope).to receive(:each).once { |&block| posts.each(&block) }

    expect(described_class.text_occurrences(scope)).to eq(
      word_occurrences: [['alpha', 2], ['beta', 2]],
      bigram_occurrences: [['alpha beta', 2]]
    )
  end
end

RSpec.describe FacebookEntry do
  include_examples 'social text analysis'
end

RSpec.describe TwitterPost do
  include_examples 'social text analysis'
end

RSpec.describe InstagramPost do
  include_examples 'social text analysis'
end

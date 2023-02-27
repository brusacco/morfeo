module WebExtractorServices
  class ExtractBigrams < ApplicationService
    def initialize(text)
      @text = text
    end

    def call
      extract_bigrams
    end
  end
end
# frozen_string_literal: true

module WebExtractorServices
  class ExtractContent < ApplicationService
    def initialize(doc, content_filter)
      @doc = doc
      @content_filter = content_filter
    end

    def call
      @doc.css('script').remove
      @doc.css('a').remove
      result = { content: @doc.at(@content_filter).text.strip }
      handle_success(result)
    end
  end
end

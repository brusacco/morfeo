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
      sanitized_string = @doc.at(@content_filter).text.strip.gsub(/[^\x00-\x7F]/, '')
      result = { content: sanitized_string }
      handle_success(result)
    end
  end
end

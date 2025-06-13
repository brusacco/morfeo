# frozen_string_literal: true

module WebExtractorServices
  class ExtractContent < ApplicationService
    def initialize(doc, content_filter)
      @doc = doc
      @content_filter = content_filter
    end

    def call
      if @doc.at(@content_filter).nil?
        handle_error('Contenido no encontrado')
      else
        @doc.css('script').remove
        @doc.css('style').remove
        @doc.css('a').remove
        sanitized_string = @doc.at(@content_filter).text.strip
        sanitized_string = sanitized_string.gsub(/[\n\r\t]/, '').squish
        result = { content: sanitized_string }
        handle_success(result)
      end
    end
  end
end

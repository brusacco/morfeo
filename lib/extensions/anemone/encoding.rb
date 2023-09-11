# frozen_string_literal: true

module Anemone
  class Page
    def doc
      return @doc if @doc

      @doc = Nokogiri::HTML(@http_response.body.force_encoding('UTF-8'))
    end
  end
end

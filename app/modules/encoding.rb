# frozen_string_literal: true

module Anemone
  class Page
    def doc
      return @doc if @doc

      begin
        @doc = Nokogiri::HTML(@body.force_encoding('UTF-8')) if @body && html?
      rescue StandardError
        nil
      end
    end
  end
end

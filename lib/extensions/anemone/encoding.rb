# frozen_string_literal: true

module Anemone
  class Page
    def doc
      return @doc if @doc

      body = @http_response.body
      
      # Try to detect encoding from Content-Type header
      # Many Paraguayan news sites use ISO-8859-1 or Windows-1252
      encoding = extract_encoding_from_header || 'UTF-8'
      
      # Properly transcode to UTF-8 (not just force_encoding)
      # This prevents mojibake with Spanish characters (á, é, í, ó, ú, ñ)
      begin
        body = body.encode('UTF-8', encoding, invalid: :replace, undef: :replace, replace: '')
      rescue Encoding::ConverterNotFoundError
        # Fallback if encoding is not recognized
        body = body.force_encoding('UTF-8').scrub('')
      end
      
      @doc = Nokogiri::HTML(body)
    end

    private

    def extract_encoding_from_header
      return nil unless @http_response&.content_type
      
      # Extract charset from Content-Type header
      # Example: "text/html; charset=ISO-8859-1"
      charset = @http_response.content_type[/charset=([^\s;]+)/i, 1]
      
      # Normalize common charset names
      case charset&.upcase
      when 'LATIN1', 'ISO-8859-1', 'ISO_8859-1'
        'ISO-8859-1'
      when 'WINDOWS-1252', 'CP1252'
        'Windows-1252'
      else
        charset
      end
    end
  end
end

# frozen_string_literal: true

require 'net/http'
require 'uri'
require 'json'

module EntityExtractor
  # HTTP client for the GLiNER entity extraction API (FastAPI, gliner2.5-multi-v1).
  #
  # POSTs the given text to the `/v1/entities` endpoint and returns the
  # extracted entities as a result object.
  #
  # Example:
  #   result = EntityExtractor::ExtractEntities.call(text: 'Santiago Peña se reunió...')
  #   if result.success?
  #     result.entities # => [{ text:, type:, confidence:, start:, end: }, ...]
  #   else
  #     result.error    # => "HTTP 500: ..." or "SocketError: ..."
  #   end
  #
  # The endpoint defaults to ENV['ENTITY_API_URL'] or DEFAULT_API_URL and can
  # be overridden per call with the `api_url:` option.
  class ExtractEntities < ApplicationService
    DEFAULT_API_URL = 'http://www.morfeo.com.py:8001/v1/entities'
    OPEN_TIMEOUT = 10
    READ_TIMEOUT = 60

    def initialize(text:, api_url: nil)
      @text = text.to_s
      @api_url = api_url.presence || ENV['ENTITY_API_URL'] || DEFAULT_API_URL
    end

    def call
      response = post_entities
      unless response.is_a?(Net::HTTPSuccess)
        return handle_error("HTTP #{response.code}: #{response.body.to_s.truncate(300)}")
      end

      payload = JSON.parse(response.body)
      handle_success({ entities: payload['entities'] || [] })
    rescue StandardError => e
      handle_error("#{e.class}: #{e.message}")
    end

    private

    def post_entities
      uri = URI.parse(@api_url)
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = (uri.scheme == 'https')
      http.open_timeout = OPEN_TIMEOUT
      http.read_timeout = READ_TIMEOUT

      request = Net::HTTP::Post.new(uri)
      request['Content-Type'] = 'application/json'
      request.body = { text: @text }.to_json

      http.request(request)
    end
  end
end

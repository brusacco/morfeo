# frozen_string_literal: true

module AiServices
  class OpenAiQuery < ApplicationService
    def initialize(text)
      @text = text
    end

    MAX_RETRIES = 3
    RETRY_BASE_DELAY = 2 # seconds (exponential: 2^attempt)

    def call
      client = OpenAI::Client.new(access_token: Rails.application.credentials.openai_access_token)
      attempt = 0

      loop do
        response = client.chat(
          parameters: {
            model: 'gpt-4.1-mini',
            messages: [{ role: 'user', content: @text }],
            temperature: 0.7
          }
        )

        # Si no hay error, sale del ciclo. Si hay error pero no es el especificado, tambien sale del ciclo
        unless response['error'].present? && response.dig('error', 'code') == 'unsupported_country_region_territory'
          result = response.dig('choices', 0, 'message', 'content')
          return handle_success(result)
        end

        attempt += 1
        return handle_error(response.dig('error', 'message') || 'OpenAI: unsupported country/region') if attempt >= MAX_RETRIES

        sleep(RETRY_BASE_DELAY**attempt)
      end
    end
  end
end

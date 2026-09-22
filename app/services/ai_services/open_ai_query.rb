# frozen_string_literal: true

module AiServices
  class OpenAiQuery < ApplicationService
    def initialize(text)
      @text = text
    end

    MAX_RETRIES = 3
    RETRY_BASE_DELAY = 2 # seconds (exponential: 2^attempt)

    def call
      client = OpenAI::Client.new(access_token: ENV.fetch('OPENAI_ACCESS_TOKEN', nil))
      attempt = 0

      loop do
        response = client.chat(
          parameters: {
            model: 'gpt-5-mini',
            messages: [{ role: 'user', content: @text }],
            temperature: 1
          }
        )

        if response['error'].present?
          if response.dig('error', 'code') == 'unsupported_country_region_territory'
            attempt += 1
            if attempt >= MAX_RETRIES
              return handle_error(response.dig('error', 'message') || 'OpenAI: unsupported country/region')
            end

            sleep(RETRY_BASE_DELAY**attempt)
            next
          end

          return handle_error(response.dig('error', 'message') || 'OpenAI request failed')
        end

        result = response.dig('choices', 0, 'message', 'content')

        if result.blank?
          return handle_error('OpenAI returned an empty response')
        end

        return handle_success(result)
      end
    end
  end
end

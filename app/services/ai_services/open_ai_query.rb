# frozen_string_literal: true

module AiServices
  class OpenAiQuery < ApplicationService
    def initialize(text)
      @text = text
    end

    def call
      client = OpenAI::Client.new(access_token: Rails.application.credentials.openai_access_token)
      response = []
      loop do
        response = client.chat(
          parameters: {
            model: 'gpt-3.5-turbo',
            messages: [{ role: 'user', content: @text }],
            temperature: 0.7
          }
        )
        # Si no hay error, sale del ciclo. Si hay error pero no es el especificado, tambien sale del ciclo
        break if !response['error'].present? || (response['error'].present? && response['error']['code'] != 'unsupported_country_region_territory')
      end

      result = response.dig('choices', 0, 'message', 'content')
      handle_success(result)
    end
  end
end

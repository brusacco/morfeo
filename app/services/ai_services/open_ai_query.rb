# frozen_string_literal: true

module AiServices
  class OpenAiQuery < ApplicationService
    def initialize(text)
      @text = text
    end

    def call
      client = OpenAI::Client.new(access_token: Rails.application.credentials.openai_access_token)
      response = client.chat(
        parameters: {
          model: 'gpt-3.5-turbo',
          messages: [{ role: 'user', content: @text }],
          temperature: 0.7
        }
      )
      result = response.dig('choices', 0, 'message', 'content')
      handle_success(result)
    end
  end
end

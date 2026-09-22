# frozen_string_literal: true

module AiServices
  class SentimentAnalysisService < ApplicationService
    PROMPT_TEMPLATE = "Analiza el sentimiento de esta noticia y responde solo con una palabra: positiva, negativa o neutra.\n\nNoticia: %s"

    def initialize(text)
      @text = text
    end

    def call
      prompt = format(PROMPT_TEMPLATE, @text)
      client = OpenAI::Client.new(access_token: ENV.fetch('OPENAI_ACCESS_TOKEN', nil))
      response = client.chat(
        parameters: {
          model: 'gpt-5-mini',
          messages: [{ role: 'user', content: prompt }],
          temperature: 1
        }
      )

      if response['error'].present?
        raise StandardError, response.dig('error', 'message') || 'OpenAI sentiment request failed'
      end

      content = response.dig('choices', 0, 'message', 'content')
      raise StandardError, 'OpenAI returned an empty sentiment response' if content.blank?

      content.to_s.strip.downcase
    end
  end
end

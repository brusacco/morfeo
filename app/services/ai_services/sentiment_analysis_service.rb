# frozen_string_literal: true

module AiServices
  class SentimentAnalysisService < ApplicationService
    PROMPT_TEMPLATE = "Analiza el sentimiento de esta noticia y clasifícala como positiva, negativa o neutra.

Noticia: %s"

    def initialize(text)
      @text = text
    end

    def call
      prompt = format(PROMPT_TEMPLATE, @text)
      client = OpenAI::Client.new(access_token: ENV.fetch('OPENAI_ACCESS_TOKEN', nil))
      response = client.chat(
        parameters: {
          model: 'gpt-5-mini',
          messages: [{ role: 'user', content: promp
      client = OpenAI::Client.new(access_token: ENV.fetch('OPENAI_ACCESS_TOKEN', nil))
      response = client.chat(
        parameters: {
          model: 'gpt-5-mini',
          messages: [{ role: 'user', content: prompt }],
          temperature: 0.7,
          response_format: {
            type: 'json_schema',
            json_schema: {
              name: 'sentiment',
              schema: {
                type: 'object',
                properties: {
                  sentiment: {
                    type: 'string',
                    enum: %w[positiva negativa neutra],
                    description: 'El sentimiento de la noticia'
                  }
                },
                required: ['sentiment'],
                additionalProperties: false
              }
            }
          }
        }
      )
      content = response.dig('choices', 0, 'message', 'content')
      parsed = JSON.parse(content)
      parsed['sentiment']
    rescue JSON::ParserError => e
      Rails.logger.warn "Failed to parse AI sentiment response: #{e.message}"
      'neutra'
    end
  end
end

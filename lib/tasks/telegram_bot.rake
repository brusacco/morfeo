# frozen_string_literal: true

require 'telegram/bot'

desc 'Telegram Bot'
task telegram_bot: :environment do
  TELEGRAM_TOKEN = Rails.application.credentials[:telegram_access_token]
  OPENAI_TOKEN = Rails.application.credentials[:openai_access_token]

  chats = []

  #--------------------------------------------------------------------
  #
  #--------------------------------------------------------------------
  def split_text(text)
    if text.length > 4000
      split_index = text.rindex(' ', 4000) || 4000
      first_part = text[0...split_index]
      second_part = text[split_index..]
      [first_part, second_part]
    else
      [text, nil]
    end
  end

  #--------------------------------------------------------------------
  #
  #--------------------------------------------------------------------
  def generate_topic_report(topico, entries)
    client = OpenAI::Client.new(access_token: OPENAI_TOKEN)

    prompt = entries.prompt(topico)

    response = client.chat(
      parameters: {
        model: 'gpt-3.5-turbo', # Required.
        messages: [{ role: 'user', content: prompt }], # Required.
        temperature: 0.7
      }
    )
    response.dig('choices', 0, 'message', 'content')
  end

  #--------------------------------------------------------------------
  #
  #--------------------------------------------------------------------
  Telegram::Bot::Client.run(TELEGRAM_TOKEN) do |bot|
    bot.listen do |message|
      case message
      when Telegram::Bot::Types::Message
        case message.text
        when '/start'
          bot.api.send_message(
            chat_id: message.chat.id,
            text: "Hola, #{message.from.first_name} bienvenido a MoopioBot."
          )
          chats << message.chat.id
        when '/stop'
          bot.api.send_message(chat_id: message.chat.id, text: "Adios, #{message.from.first_name}")
        when '/populares'
          entries = Entry.includes(:site).where(total_count: 1..).a_day_ago.order(total_count: :desc).limit(10)
          bot.api.send_message(
            chat_id: message.chat.id,
            text: 'A continuacion, mostramos las 10 noticias mas importantes'
          )
          entries.each do |entry|
            bot.api.send_message(chat_id: message.chat.id, text: "#{entry.title} #{entry.url}")
          end
        when '/recientes'
          entries = @entries = Entry.includes(:site).order(published_at: :desc).limit(10)
          bot.api.send_message(
            chat_id: message.chat.id,
            text: 'A continuacion, mostramos las 10 noticias mas recientes'
          )
          entries.each do |entry|
            bot.api.send_message(chat_id: message.chat.id, text: "#{entry.title} #{entry.url}")
          end
        when %r{^/tema (.+)}
          tema = message&.text&.gsub('/tema ', '')
          topic = Topic.find_by(name: tema)

          if topic
            tags = topic.tags.pluck(:name)
            entries = Entry.includes(:site).a_week_ago.tagged_with(tags, any: true).order(total_count: :desc).limit(10)
          end

          if topic.nil? || entries.empty?
            bot.api.send_message(chat_id: message.chat.id, text: 'No se encontro este tema')
          else
            bot.api.send_message(
              chat_id: message.chat.id,
              text: "A continuacion, mostramos los 10 noticias mas importantes en el tema #{topic.name}"
            )
            entries.each do |entry|
              bot.api.send_message(
                chat_id: message.chat.id,
                text: "#{entry.title} - Interacciones: #{entry.total_count} #{entry.url}"
              )
            end
          end
        when %r{^/etiqueta (.+)}
          etiqueta = message&.text&.gsub('/etiqueta ', '')
          entries = Entry.includes(:site).a_week_ago.tagged_with(
            etiqueta,
            any: true
          ).order(total_count: :desc).limit(10)

          if entries.empty?
            bot.api.send_message(chat_id: message.chat.id, text: 'No se encontro este tema')
          else
            bot.api.send_message(
              chat_id: message.chat.id,
              text: "A continuacion, mostramos los 10 noticias mas importantes en el tema #{etiqueta}"
            )
            entries.each do |entry|
              bot.api.send_message(
                chat_id: message.chat.id,
                text: "#{entry.title} - Interacciones: #{entry.total_count} #{entry.url}"
              )
            end
          end
        when '/temas'
          @topics = Topic.all
          bot.api.send_message(
            chat_id: message.chat.id,
            text: "A continuacion, mostramos los topicos: #{@topics.pluck(:name).join(',')}"
          )
        when '/topicos'
          @topics = Topic.all
          button_options = @topics.map { |topic| { text: topic.name, callback_data: "/topico #{topic.name}" } }

          bot.api.send_message(
            chat_id: message.chat.id,
            text: 'A continuación, mostramos los tópicos:',
            reply_markup: { inline_keyboard: button_options.each_slice(2).to_a }.to_json
          )
        end
      when Telegram::Bot::Types::CallbackQuery
        case message.data
        when %r{^/etiqueta (.+)}
          selected_option = message.data.gsub('/etiqueta ', '')
          entries = Entry.includes(:site).a_week_ago.tagged_with(selected_option).order(total_count: :desc).limit(10)

          if entries.empty?
            bot.api.send_message(chat_id: message.from.id, text: 'No se encontro este tema')
          else
            bot.api.send_message(
              chat_id: message.from.id,
              text: "A continuacion, mostramos los 10 noticias mas importantes en el tema #{selected_option}"
            )
            entries.each do |entry|
              bot.api.send_message(
                chat_id: message.from.id,
                text: "#{entry.title} - Interacciones: #{entry.total_count} #{entry.url}"
              )
            end
          end
        when %r{^/topico (.+)}
          selected_option = message.data.gsub('/topico ', '')
          topic = Topic.find_by(name: selected_option)

          if topic
            tags = topic.tags.pluck(:name)
            entries = Entry.includes(:site).a_week_ago.tagged_with(tags, any: true).order(total_count: :desc).limit(10)
          end

          if topic.nil? || entries.empty?
            bot.api.send_message(chat_id: message.from.id, text: 'No se encontro este tema')
          else
            bot.api.send_message(
              chat_id: message.from.id,
              text: "A continuacion, mostramos los 10 noticias mas importantes en el tema #{topic.name}"
            )
            entries.each do |entry|
              bot.api.send_message(
                chat_id: message.from.id,
                text: "#{entry.title} - Interacciones: #{entry.total_count} #{entry.url}"
              )
            end

            # content = generate_topic_report(topic.name, entries)
            content = topic.reports.last.report_text
            bot.api.send_message(chat_id: message.from.id, text: content)

            button_options = tags.map { |tag| { text: tag, callback_data: "/etiqueta #{tag}" } }
            bot.api.send_message(
              chat_id: message.from.id,
              text: 'Estas son las etiquetas de este topico:',
              reply_markup: { inline_keyboard: button_options.each_slice(2).to_a }.to_json
            )
          end
        end
      end
    end
  end
end

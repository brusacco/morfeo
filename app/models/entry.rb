# frozen_string_literal: true

class Entry < ApplicationRecord
  acts_as_taggable_on :tags
  validates :url, uniqueness: true
  belongs_to :site, touch: true

  scope :a_day_ago, -> { where(published_at: 1.day.ago..) }
  scope :a_week_ago, -> { where(published_at: 1.week.ago..) }
  scope :a_month_ago, -> { where(published_at: 1.month.ago..) }
  scope :normal_range, -> { where(published_at: DAYS_RANGE.days.ago..) }
  scope :has_image, -> { where.not(image_url: nil) }
  scope :has_interactions, -> { where(total_count: 10..) }
  scope :has_any_interactions, -> { where(total_count: 1..) }

  enum polarity: { neutral: 0, positive: 1, negative: 2 }

  before_save :set_published_date

  def self.positives
    positives = []
    all.find_each do |entry|
      positives << entry.id if entry.positive?
    end
    positives
  end

  def self.prompt(topic)
    text = ''
    separator = '####'
    all.find_each do |entry|
      text += "Titulo: #{entry.title}\n"
      text += "Description: #{entry.description}\n"
      text += "#{separator}\n"
    end

    "En el rol de un analista de PR por favor, resume brevemente las siguientes noticias relacionadas con #{topic} separadas por #{separator}\n#{text}
    \nnecesito que el resumen sea general en un parrafo y no una lista.
    Identifica las categorías o áreas temáticas más relevantes presentes en las noticias.
    Identifica las historias que están recibiendo más atención y considera cómo se relacionan entre sí.
    Analiza el tono y las opiniones expresadas en las noticias utilizando técnicas de análisis de sentimientos."
  end

  def self.generate_report(topic)
    prompt = all.prompt(topic)
    response = AiServices::OpenAiQuery.call(prompt)
    return unless response.success?

    response.data
  end

  def self.bigram_occurrences(limit = 100)
    word_occurrences = Hash.new(0)

    all.find_each do |entry|
      words = "#{entry.title} #{entry.content}".gsub(/[[:punct:]]/, '').split
      bigrams = words.each_cons(2).map { |word1, word2| "#{word1.downcase} #{word2.downcase}" }
      bigrams.each do |bigram|
        next if bigram.split.first.length <= 2 || bigram.split.last.length <= 2
        next if STOP_WORDS.include?(bigram.split.first) || STOP_WORDS.include?(bigram.split.last)
        next if [
          'artículos relacionados',
          'adn digital',
          'share tweet',
          'tweet share',
          'copy link',
          'link copied'
        ].include?(bigram)

        word_occurrences[bigram] += 1
      end
    end

    word_occurrences.select { |_bigram, count| count > 1 }
                    .sort_by { |_k, v| v }
                    .reverse
                    .take(limit)
  end

  def self.word_occurrences(limit = 100)
    word_occurrences = Hash.new(0)

    all.find_each do |entry|
      words = "#{entry.title} #{entry.content}".gsub(/[[:punct:]]/, ' ').split
      words.each do |word|
        cleaned_word = word.downcase
        next if STOP_WORDS.include?(cleaned_word)
        next if cleaned_word.length <= 2
        next if ['https'].include?(cleaned_word)

        word_occurrences[cleaned_word] += 1
      end
    end

    word_occurrences.select { |_word, count| count > 1 }
                    .sort_by { |_k, v| v }
                    .reverse
                    .take(limit)
  end

  def set_polarity(force: false)
    return polarity unless polarity.nil?

    sleep 5

    text = "Analizar el sentimiento de la siguente noticia:
    #{title} #{description} #{content} #{tag_list}
    Responder solo con las palabras negativa, positiva o neutra.
    Considere elementos como tono, contexto y palabras clave para realizar el análisis de sentimientos de manera más precisa.
    En caso de no poder analizar responder neutra."

    ai_polarity = call_ai(text)
    if ai_polarity == 'negativa'
      update!(polarity: :negative)
    elsif ai_polarity == 'positiva'
      update!(polarity: :positive)
    else
      update!(polarity: :neutral)
    end
    polarity
  end

  def belongs_to_any_topic?
    Topic.all.any? { |topic| (topic.tag_ids & tag_ids).any? }
  end

  def clean_image
    if image_url.blank? || image_url == 'null'
      'https://via.placeholder.com/300x250'
    else
      image_url
    end
  end

  def all_tags
    response = []
    response << tags.map(&:name)
    tags.each do |tag|
      response << tag.variations.gsub(', ', ',').split(',') if tag.variations
    end
    response.uniq.flatten
  end

  def bigrams
    return bigram_list if bigram_list.present?

    bigram_list.add(ngrams(2))
    # save
    # bigram_list
  end

  def trigrams
    return trigram_list if trigram_list.present?

    trigram_list.add(ngrams(3))
    # save
    # trigram_list
  end

  private

  def call_ai(text)
    client = OpenAI::Client.new(access_token: Rails.application.credentials.openai_access_token)
    response = client.chat(
      parameters: {
        model: 'gpt-3.5-turbo', # Required.
        messages: [{ role: 'user', content: text }], # Required.
        temperature: 0.7
      }
    )
    response.dig('choices', 0, 'message', 'content')
  end

  def ngrams(n = 2)
    # regex = /([A-ZÀ-Ö][a-zø-ÿ]{3,})\s([A-ZÀ-Ö][a-zø-ÿ]{3,})/
    regex = /([a-zø-ÿ]{3,})\s([a-zø-ÿ]{3,})/
    bad_words = %w[Noticias Internacional Radio Noticiero Desde]
    bad_words += %w[
      sos
      es
      pero
      del
      de
      desde
      donde
      el
      los
      las
      la
      abc
      una
      un
      no
      mas
      por
      como
      que
      con
      para
      las
      fue
      más
      se
      su
      sus
      en
      al
    ]
    bad_words += STOP_WORDS

    ngrams = []
    words = clean_text(title).split + clean_text(description).split + clean_text(content).split

    words.each_cons(n).each do |ngram|
      tag = ngram.join(' ')
      ngrams << tag if tag.match(regex) && !contains_substring?(tag, bad_words)
    end

    ngrams.uniq
  end

  def clean_text(text)
    return '' if text.nil?

    text = text.gsub(/\d/, '')
    text = text.gsub(/[[:punct:]]/, ' ')
    text.downcase!
    text.strip!
    text
  end

  def set_published_date
    self.published_date = published_at.to_date if published_at.present?
  end

  def contains_substring?(string, substrings)
    # substrings.any? { |substring| string.scan(substring).any? }
    # substrings.any? { |substring| string.scan(/\b#{substrings}\b/).any? }
    substrings.each do |substring|
      return true if string.match(/\b#{substring}\b/)
    end
    false
  end
end

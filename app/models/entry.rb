# frozen_string_literal: true

class Entry < ApplicationRecord
  # Disable Elasticsearch indexing since we're using direct associations now
  searchkick callbacks: false
  acts_as_taggable_on :tags, :title_tags
  validates :url, uniqueness: true
  belongs_to :site, touch: true
  has_many :comments, dependent: :destroy
  has_one :twitter_post, dependent: :nullify

  # NEW: Direct topic associations for performance optimization
  has_many :entry_topics, dependent: :destroy
  has_many :topics, through: :entry_topics

  has_many :entry_title_topics, dependent: :destroy
  has_many :title_topics, through: :entry_title_topics, source: :topic

  # NEW: Auto-sync callbacks (critical for keeping associations up to date)
  after_save :sync_topics_from_tags, if: :saved_change_to_tag_list?
  after_save :sync_title_topics_from_tags, if: :saved_change_to_title_tag_list?

  alias_attribute :habilitar_Deshabilitar_Notas, :enabled
  alias_attribute :notas_Repetidas, :repeated

  attribute :repeateds, :integer
  enum :repeateds, { No: 0, Si: 1, Limpiado: 2 }

  # Pre-compiled regex and bad words set for performance
  NGRAM_REGEX = /\b([a-zø-ÿ]{3,})\s([a-zø-ÿ]{3,})\b/i
  BAD_WORDS = Set.new(
    %w[
      noticias
      internacional
      radio
      noticiero
      desde
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
    ] + STOP_WORDS
  ).freeze

  scope :a_day_ago, -> { where(published_at: 1.day.ago..) }
  scope :a_week_ago, -> { where(published_at: 1.week.ago..) }
  scope :a_month_ago, -> { where(published_at: 1.month.ago..) }
  scope :normal_range, -> { where(published_at: DAYS_RANGE.days.ago..) }
  scope :has_image, -> { where.not(image_url: nil) }
  scope :has_interactions, -> { where(total_count: 10..) }
  scope :has_any_interactions, -> { where(total_count: 1..) }
  scope :enabled, -> { where(enabled: true) }
  scope :disabled, -> { where(enabled: false) }

  enum :polarity, { neutral: 0, positive: 1, negative: 2 }

  before_save :set_published_date

  def self.positives
    where(polarity: :positive).pluck(:id)
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

    pluck(:title, :content).each do |title, content|
      words = "#{title} #{content}".gsub(/[[:punct:]]/, '').split
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

    pluck(:title, :content).each do |title, content|
      words = "#{title} #{content}".gsub(/[[:punct:]]/, ' ').split
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

  def self.tagged_on_entry_quantity(tag, date)
    tagged_with(tag, any: true).tagged_date(date).size
  end

  def self.tagged_on_entry_interaction(tag, date)
    tagged_with(tag, any: true).tagged_date(date).sum(:total_count)
  end

  def self.tagged_on_neutral_quantity(tag, date)
    tagged_with(tag, any: true).tagged_date(date).where(polarity: 0).size
  end

  def self.tagged_on_positive_quantity(tag, date)
    tagged_with(tag, any: true).tagged_date(date).where(polarity: 1).size
  end

  def self.tagged_on_negative_quantity(tag, date)
    tagged_with(tag, any: true).tagged_date(date).where(polarity: 2).size
  end

  def self.tagged_on_neutral_interaction(tag, date)
    tagged_with(tag, any: true).tagged_date(date).where(polarity: 0).sum(:total_count)
  end

  def self.tagged_on_positive_interaction(tag, date)
    tagged_with(tag, any: true).tagged_date(date).where(polarity: 1).sum(:total_count)
  end

  def self.tagged_on_negative_interaction(tag, date)
    tagged_with(tag, any: true).tagged_date(date).where(polarity: 2).sum(:total_count)
  end

  # Title
  def self.tagged_on_title_entry_quantity(tag, date)
    tagged_with(tag, on: :title_tags, any: true).tagged_date(date).size
  end

  def self.tagged_on_title_entry_interaction(tag, date)
    tagged_with(tag, on: :title_tags, any: true).tagged_date(date).sum(:total_count)
  end

  def search_data
    {
      title: title,
      description: description,
      content: content,
      published_at: published_at,
      published_date: published_date,
      total_count: total_count,
      tags: tag_list,
      title_tags: title_tag_list
    }
  end

  def set_polarity(force: false)
    # Skip if polarity already set (unless forced)
    return polarity if polarity.present? && !force

    sleep 5

    text = "Analizar el sentimiento de la siguente noticia:
    #{title} #{description} #{content} #{tag_list}
    Responder solo con las palabras negativa, positiva o neutra.
    Considere elementos como tono, contexto y palabras clave para realizar el análisis de sentimientos de manera más precisa.
    En caso de no poder analizar responder neutra."

    ai_polarity = call_ai(text)
    if %w[negativa Negativa].include?(ai_polarity)
      update!(polarity: :negative)
    elsif %w[positiva Positiva].include?(ai_polarity)
      update!(polarity: :positive)
    else
      update!(polarity: :neutral)
    end
    polarity
  end

  def belongs_to_any_topic?
    Topic.joins(:tags).where(tags: { id: tag_ids }).exists?
  end

  def clean_image
    if image_url.blank? || image_url == 'null'
      if site.page && site.page.picture.present?
        site.page.picture
      else
        ActionController::Base.helpers.asset_path('default-entry.svg')
      end
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

  # NEW: Sync regular tags to topics
  # This is PUBLIC so it can be called from rake tasks and background jobs
  def sync_topics_from_tags
    return if tag_list.empty?

    # Convert TagList to array of strings for SQL query
    tag_names = tag_list.map(&:to_s)
    
    # Find all topics that have tags matching this entry's tags
    # Using explicit IN query to ensure compatibility with acts_as_taggable_on
    matching_topics = Topic.joins(:tags)
                          .where('tags.name IN (?)', tag_names)
                          .distinct

    # Update the association (Rails handles the join table)
    self.topics = matching_topics

    Rails.logger.info "Entry #{id}: Synced #{matching_topics.count} topics from #{tag_names.size} tags"
  rescue => e
    Rails.logger.error "Entry #{id}: Failed to sync topics - #{e.message}"
    # Don't raise - this shouldn't break entry creation
  end

  # NEW: Sync title tags to topics
  # This is PUBLIC so it can be called from rake tasks and background jobs
  def sync_title_topics_from_tags
    return if title_tag_list.empty?

    # Convert TagList to array of strings for SQL query
    title_tag_names = title_tag_list.map(&:to_s)
    
    # Find all topics that have tags matching this entry's title tags
    # Using explicit IN query to ensure compatibility with acts_as_taggable_on
    matching_topics = Topic.joins(:tags)
                          .where('tags.name IN (?)', title_tag_names)
                          .distinct

    # Update the association
    self.title_topics = matching_topics

    Rails.logger.info "Entry #{id}: Synced #{matching_topics.count} title topics from #{title_tag_names.size} title tags"
  rescue => e
    Rails.logger.error "Entry #{id}: Failed to sync title topics - #{e.message}"
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
    # regex = /([a-zø-ÿ]{3,})\s([a-zø-ÿ]{3,})/
    # bad_words = %w[Noticias Internacional Radio Noticiero Desde]
    # bad_words += %w[
    #   sos
    #   es
    #   pero
    #   del
    #   de
    #   desde
    #   donde
    #   el
    #   los
    #   las
    #   la
    #   abc
    #   una
    #   un
    #   no
    #   mas
    #   por
    #   como
    #   que
    #   con
    #   para
    #   las
    #   fue
    #   más
    #   se
    #   su
    #   sus
    #   en
    #   al
    # ]
    # bad_words += STOP_WORDS

    ngrams = []
    words = clean_text(title).split + clean_text(description).split + clean_text(content).split

    words.each_cons(n).each do |ngram|
      tag = ngram.join(' ')
      ngrams << tag if tag.match(NGRAM_REGEX) && !contains_substring?(tag)
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

  def contains_substring?(string)
    BAD_WORDS.any? { |word| string.include?(word) }
  end

  # For TopicStatDaily
  scope :tagged_date, ->(date) { where(published_at: date.all_day) }

  # NEW: Scoped queries for direct topic lookups
  scope :for_topic, ->(topic) {
    topic_id = topic.is_a?(Topic) ? topic.id : topic
    joins(:entry_topics).where(entry_topics: { topic_id: topic_id })
  }

  scope :for_topic_title, ->(topic) {
    topic_id = topic.is_a?(Topic) ? topic.id : topic
    joins(:entry_title_topics).where(entry_title_topics: { topic_id: topic_id })
  }
end

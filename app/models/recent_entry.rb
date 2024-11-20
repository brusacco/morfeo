# frozen_string_literal: true

class RecentEntry < ApplicationRecord
  acts_as_taggable_on :tags
  belongs_to :site, touch: true

  def self.positives
    positives = []
    find_each do |entry|
      positives << entry.id if entry.positive?
    end
    positives
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

  def belongs_to_any_topic?
    Topic.all.any? { |topic| (topic.tag_ids & tag_ids).any? }
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
end

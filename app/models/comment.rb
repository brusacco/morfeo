# frozen_string_literal: true

class Comment < ApplicationRecord
  belongs_to :entry, touch: true

  def self.word_occurrences(limit = 100)
    word_occurrences = Hash.new(0)

    find_each do |comment|
      words = comment.message.gsub(/[[:punct:]]/, ' ').split
      words.each do |word|
        cleaned_word = word.downcase
        next if STOP_WORDS.include?(cleaned_word)
        next if cleaned_word.length <= 2
        next if %w[https www com].include?(cleaned_word)

        word_occurrences[cleaned_word] += 1
      end
    end

    word_occurrences.select { |_word, count| count > 1 }
                    .sort_by { |_k, v| v }
                    .reverse
                    .take(limit)
  end

  def self.bigram_occurrences(limit = 100)
    word_occurrences = Hash.new(0)

    # Bad words array, including common stop words and some political ones.
    bad_words_array = %w[http que les para eso la su sus por yo mi nos tu ellos ellas nosotros]
    bad_words_array += STOP_WORDS

    find_each do |comment|
      words = comment.message.gsub(/[[:punct:]]/, '').split
      bigrams = words.each_cons(2).map { |word1, word2| "#{word1.downcase} #{word2.downcase}" }
      bigrams.each do |bigram|
        next if bigram.split.first.length <= 2 || bigram.split.last.length <= 2
        next if contains_substring?(bigram, bad_words_array)

        word_occurrences[bigram] += 1
      end
    end

    word_occurrences.select { |_bigram, count| count > 1 }
                    .sort_by { |_k, v| v }
                    .reverse
                    .take(limit)
  end

  def self.contains_substring?(string, substrings_array)
    substrings_array.each do |substring|
      return true if string.match(/\b#{substring}\b/)
    end
    false
  end
end

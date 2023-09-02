# frozen_string_literal: true

class ApplicationController < ActionController::Base
  def word_occurrences(entries, limit = 50)
    word_occurrences = Hash.new(0)

    entries.each do |entry|
      words = "#{entry.title} #{entry.content}".gsub(/[[:punct:]]/, '').split
      words.each do |word|
        cleaned_word = word.downcase
        next if STOP_WORDS.include?(cleaned_word) || cleaned_word.length <= 1

        word_occurrences[cleaned_word] += 1
      end
    end

    word_occurrences.select { |_word, count| count > 10 }
                    .sort_by { |_k, v| v }
                    .reverse
                    .take(limit)
  end

  def bigram_occurrences(entries, limit = 50)
    word_occurrences = Hash.new(0)

    entries.each do |entry|
      words = "#{entry.title} #{entry.content}".gsub(/[[:punct:]]/, '').split
      bigrams = words.each_cons(2).map { |word1, word2| "#{word1.downcase} #{word2.downcase}" }
      bigrams.each do |bigram|
        next if STOP_WORDS.include?(bigram.split.first) || STOP_WORDS.include?(bigram.split.last)

        word_occurrences[bigram] += 1
      end
    end

    word_occurrences.select { |_bigram, count| count > 10 }
                    .sort_by { |_k, v| v }
                    .reverse
                    .take(limit)
  end
end

# frozen_string_literal: true

class ApplicationController < ActionController::Base
  before_action :set_paper_trail_whodunnit
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
    occurrences = Hash.new(0)

    entries.each do |entry|
      words = "#{entry.title} #{entry.content}".gsub(/[[:punct:]]/, '').split
      bigrams = words.each_cons(2).map { |word1, word2| "#{word1.downcase} #{word2.downcase}" }
      bigrams.each do |bigram|
        next if STOP_WORDS.include?(bigram.split.first) || STOP_WORDS.include?(bigram.split.last)

        occurrences[bigram] += 1
      end
    end

    occurrences.select { |_bigram, count| count > 5 }
               .sort_by { |_k, v| v }
               .reverse
               .take(limit)
  end

  before_action :user_topics

  protected

  def user_for_paper_trail
    admin_user_signed_in? ? current_admin_user.try(:id) : 'Unknown user'
  end

  private

  def user_topics
    return unless user_signed_in?

    @topicos = current_user.topics.where(status: true)
  end
end

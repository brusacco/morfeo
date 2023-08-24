# frozen_string_literal: true

class TagController < ApplicationController
  def show
    @tag = Tag.find(params[:id])
    @entries = Entry.normal_range.joins(:site).tagged_with(@tag.name).has_image.order(published_at: :desc)
    @total_entries = @entries.size
    @total_interactions = @entries.sum(:total_count)

    @word_occurrences = word_occurrences_from_entries(@entries)
    @bigram_occurrences = bigram_occurrences_from_entries(@entries)

    @top_entries = Entry.normal_range.joins(:site).order(total_count: :desc).limit(5)

    @most_interactions = @entries.sort_by(&:total_count).reverse.take(8)

    if @total_entries.zero?
      @promedio = 0
    else
      @promedio = @total_interactions / @total_entries
    end

    @tags = @entries.tag_counts_on(:tags).order('count desc').limit(20)

    @tags_interactions = {}
    @tags.each do |tag|
      @entries.each do |entry|
        next unless entry.tag_list.include?(tag.name)

        tag.interactions ||= 0
        tag.interactions += entry.total_count

        @tags_interactions[tag.name] ||= 0
        @tags_interactions[tag.name] += entry.total_count
      end
    end

    @tags_interactions = @tags_interactions.sort_by { |_k, v| v }
                                           .reverse

    @tags_count = {}
    @tags.each { |n| @tags_count[n.name] = n.count }
  end

  def report
    @tag = Tag.find(params[:id])
    @entries = Entry.normal_range.joins(:site).tagged_with(@tag.name).has_image.order(published_at: :desc)
    @tags = @entries.tag_counts_on(:tags).order('count desc').limit(20)

    @tags_interactions = {}
    @tags.each do |tag|
      @entries.each do |entry|
        next unless entry.tag_list.include?(tag.name)

        tag.interactions ||= 0
        tag.interactions += entry.total_count

        @tags_interactions[tag.name] ||= 0
        @tags_interactions[tag.name] += entry.total_count
      end
    end

    @tags_interactions = @tags_interactions.sort_by { |_k, v| v }
                                           .reverse

    @tags_count = {}
    @tags.each { |n| @tags_count[n.name] = n.count }

    render layout: false
  end

  def search
    query = params[:query].strip
    @tags = Tag.where('name LIKE?', "%#{query}%")
  end

  private

  def bigram_occurrences_from_entries(entries)
    word_occurrences = Hash.new(0)

    entries.each do |entry|
      words = (entry.title.to_s + ' ' + entry.content.to_s).gsub(/[[:punct:]]/, '').split
      bigrams = words.each_cons(2).map { |word1, word2| "#{word1.downcase} #{word2.downcase}" }
      bigrams.each do |bigram|
        next if STOP_WORDS.include?(bigram.split.first) || STOP_WORDS.include?(bigram.split.last)

        word_occurrences[bigram] += 1
      end
    end

    word_occurrences.select { |_bigram, count| count > 10 }.sort_by { |_k, v| v }.reverse
  end

  def word_occurrences_from_entries(entries)
    word_occurrences = Hash.new(0)

    entries.each do |entry|
      words = (entry.title.to_s + ' ' + entry.content.to_s).gsub(/[[:punct:]]/, '').split
      words.each do |word|
        cleaned_word = word.downcase
        next if STOP_WORDS.include?(cleaned_word) || cleaned_word.length <= 1

        word_occurrences[cleaned_word] += 1
      end
    end

    word_occurrences.select { |_word, count| count > 10 }.sort_by { |_k, v| v }.reverse
  end
end

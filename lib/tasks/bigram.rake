# frozen_string_literal: true

desc 'Bigram Analizer'
task bigrams: :environment do
  freq = {}
  bigrams = {}
  bad_words = %w[del de desde donde el los las la abc una un no mas por como que con para las fue más se su sus en al]
  bad_words = File.readlines('stop-words.txt')

  Entry.where.not(title: nil).each do |entry|
    entry.title.strip.downcase.split.each do |word|
      if word.length > 1 && bad_words.exclude?(word)
        freq[word] = freq[word] ? freq[word] + 1 : 1
      end
    end
    entry.title.strip.downcase.split.each_cons(2).to_a.each do |word|
      word1 = word[0]
      word2 = word[1]
      if word1.length > 1 && word2.length > 2 && bad_words.exclude?(word1) && bad_words.exclude?(word2)
        word = word.join(' ').parameterize(separator: ' ')
        bigrams[word] = bigrams[word] ? bigrams[word] + 1 : 1
      end
    end
  end
  puts freq.select { |k, v| v > 10 && k.length > 3 }
  # puts bigrams.select{ |k, v| v > 10 && k.length > 3 }
end

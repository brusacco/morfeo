# frozen_string_literal: true

desc 'Bigram Analizer'
task bigrams: :environment do
  freq = {}
  File.readlines('stop-words.txt')

  freq = {}
  Entry.a_month_ago.where.not(title: nil).each do |entry|
    entry.generate_bigrams.each do |bigram|
      freq[bigram] = 0 unless freq[bigram]
      freq[bigram] += 1
    end
  end

  freq.each do |k, v|
    puts "#{k} #{v}" if v > 10
  end
end

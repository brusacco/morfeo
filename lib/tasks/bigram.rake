# frozen_string_literal: true

desc 'Bigram Analizer'
task bigrams: :environment do
  freq = {}
  bigrams = {}
  bad_words = %w[del de desde donde el los las la abc una un no mas por como que con para las fue más se su sus en al]
  bad_words = File.readlines('stop-words.txt')

  Entry.a_month_ago.where.not(title: nil).each do |entry|
    puts entry.generate_bigrams
  end
end

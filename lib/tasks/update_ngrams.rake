# frozen_string_literal: true

desc 'Update NGRAMS'
task update_ngrams: :environment do
  Entry.order(published_at: :desc).limit(1000).each do |entry|
    next if entry.bigram_list.blank?

    puts "Updating NGrams for #{entry.title} - #{entry.published_at}"
    entry.bigrams if entry.bigram_list.blank?
    entry.trigrams if entry.trigram_list.blank?
  end
end

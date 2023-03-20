# frozen_string_literal: true

desc 'Update NGRAMS'
task update_ngrams: :environment do
  Entry.a_month_ago.each do |entry|
    next unless entry.bigram_list.blank?

    puts "Updating NGrams for #{entry.id} - #{entry.published_at}"
    entry.bigrams if entry.bigram_list.blank?
    entry.trigrams if entry.trigram_list.blank?
  rescue 
    next
  end
end


task update_ngrams_tags: :environment do
  Tag.all.each do |tag|
    puts "Updating NGrams for #{tag.name} - #{tag.id}"
    Parallel.each(Entry.tagged_with(tag.name), in_threads: 5) do |entry|
      next unless entry.bigram_list.blank?

      puts "Updating NGrams for #{entry.id} - #{entry.published_at}"
      entry.bigrams if entry.bigram_list.blank?
      entry.trigrams if entry.trigram_list.blank?
    end
  rescue 
    next
  end
end

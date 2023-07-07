# frozen_string_literal: true

desc 'Update NGRAMS'
task update_ngrams: :environment do
  Entry.a_month_ago.each do |entry|
    next if entry.bigram_list.present?

    puts "Updating NGrams for #{entry.id} - #{entry.published_at}"
    entry.bigrams if entry.bigram_list.blank?
    entry.trigrams if entry.trigram_list.blank?
  rescue StandardError
    next
  end
end

task update_ngrams_tags: :environment do
  Tag.all.each do |tag|
    puts "Updating NGrams for #{tag.name} - #{tag.id}"
    Parallel.each(Entry.normal_range.tagged_with(tag.name), in_threads: 5) do |entry|
      puts "Updating NGrams for #{entry.id} - #{entry.published_at}"
      entry.bigrams
      entry.trigrams
    rescue StandardError
      next
    end
  rescue StandardError
    next
  end
end

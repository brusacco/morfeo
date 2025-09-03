# frozen_string_literal: true

namespace :ai do
  # Helper function to reindex entries for a list of tags
  def reindex_entries_for_tags(tags)
    tags.each do |tag|
      next if tag.name.blank?

      entries = Entry.tagged_with(tag.name, any: true)
      puts "Found #{entries.count} entries tagged with '#{tag}'"
      entries.find_each do |entry|
        entry.reindex
        puts "Reindexed entry ##{entry.id}: #{entry.title}"
      end
    end
    puts 'Reindexing complete.'
  end

  desc 'Update topic polarities'
  task set_topic_polarity: :environment do
    Topic.where(status: true).find_each do |topic|
      puts topic.name
      puts '--------------------------------'
      Parallel.each(topic.list_entries.where(polarity: nil), in_threads: 5) do |entry|
        entry.set_polarity
        puts entry.id
        puts entry.title
        puts entry.polarity
        puts '--------------------------------'
        sleep 1
      end
      # Reindex all entries for this topic's tags
      puts "Reindexing entries for topic: #{topic.name} #{topic.id}"
      reindex_entries_for_tags(topic.tags)
    end
  end
end

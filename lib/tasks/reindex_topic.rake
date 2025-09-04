# frozen_string_literal: true

namespace :util do
  # Helper function to reindex entries for a list of tags
  def reindex_entries_for_tags(tags)
    tags.each do |tag|
      next if tag.name.blank?

      entries = Entry.tagged_with(tag.name, any: true).limit(500)
      puts "Found entries tagged with '#{tag.name}'"
      entries.find_each do |entry|
        entry.reindex
        puts "Reindexed entry ##{entry.id}: #{entry.title}"
      end
    end
    puts 'Reindexing complete.'
  end

  desc 'Update topic polarities'
  task reindex_topic: :environment do
    tags = []
    Topic.where(status: true).find_each do |topic|
      topic.tags.each do |tag|
        tags << tag.name
        # Add variations as Tag-like OpenStructs for reindexing
        next if tag.variations.blank?

        tag.variations.split(',').each do |variation|
          next if variation.blank?

          tags << variation
        end
      end
    end
    reindex_entries_for_tags(tags.uniq)
  end
end

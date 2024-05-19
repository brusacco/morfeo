# frozen_string_literal: true

namespace :ai do
  desc 'Update topic polarities'
  task set_topic_polarity: :environment do
    Topic.all.find_each do |topic|
      puts topic.name
      puts '--------------------------------'
      Parallel.each(topic.topic_entries.where(polarity: nil), in_threads: 5) do |entry|
        entry.set_polarity
        puts entry.id
        puts entry.title
        puts entry.polarity
        puts '--------------------------------'
      end
    end
  end
end

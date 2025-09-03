# frozen_string_literal: true

namespace :ai do
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
    end
  end
end

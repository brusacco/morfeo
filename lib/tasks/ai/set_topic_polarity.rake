# frozen_string_literal: true

namespace :ai do
  desc 'Update topic polarities'
  task set_topic_polarity: :environment do
    Topic.all.find_each do |topic|
      entries = topic.topic_entries

      Parallel.each(entries, in_threads: 5).each do |entry|
        entry.set_polarity
        puts entry.title
        puts entry.polarity
        puts '--------------------------------'
      end
    rescue StandardError => e
      puts e.message
      sleep 10
      retry
    end
  end
end

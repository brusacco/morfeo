# frozen_string_literal: true

namespace :ai do
  desc 'Update topic polarities'
  task set_topic_polarity: :environment do
    Topic.all.find_each do |topic|
      Parallel.each(topic.topic_entries, in_threads: 5) do |entry|
        next unless entry.polarity.nil?
        entry.set_polarity
        puts entry.id
        puts entry.title
        puts entry.polarity
        puts '--------------------------------'
      end
    end
  end
end

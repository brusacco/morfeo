# frozen_string_literal: true

namespace :ai do
  desc 'Update topic polarities'
  task set_topic_polarity: :environment do
    topic = Topic.find(9)
    entries = @topic.topic_entries

    entries = Entry.where(polarity: nil).order(published_at: :desc).limit(200)
    entries.each do |entry|
      entry.set_polarity
      puts entry.title
      puts entry.polarity
      puts '--------------------------------'
      sleep 5
    end
  end
end

# frozen_string_literal: true

namespace :ai do
  desc 'Update polarities'
  task set_polarity: :environment do
    entries = Entry.order(published_at: :desc).limit(100)
    entries.each do |entry|
      entry.set_polarity
      puts entry.title
      puts entry.polarity
      puts '--------------------------------'
    end
  end
end

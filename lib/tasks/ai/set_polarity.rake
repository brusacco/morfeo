# frozen_string_literal: true

namespace :ai do
  desc 'Update polarities'
  task set_polarity: :environment do
    entries = Entry.where.not(polarity: nil).order(published_at: :desc).limit(200)
    entries.each do |entry|
      entry.set_polarity
      puts entry.title
      puts entry.polarity
      puts '--------------------------------'
    end
  end
end

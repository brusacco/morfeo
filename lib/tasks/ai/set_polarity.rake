# frozen_string_literal: true

namespace :ai do
  desc 'Update polarities'
  task set_polarity: :environment do
    entries = Entry.enabled.where(polarity: nil).order(published_at: :desc).limit(500)
    entries.each do |entry|
      entry.set_polarity
      puts entry.title
      puts entry.polarity
      puts '--------------------------------'
    end
  end
end

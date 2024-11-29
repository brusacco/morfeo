# frozen_string_literal: true

namespace :dev do
  desc 'Generate Random Polarities'
  task fake_polarities: :environment do
    entries = Entry.normal_range.enabled
    polarities = [0, 1, 2]

    entries.each do |entry|
      entry.polarity = polarities.sample
      entry.save!
    end

    puts "Random polarities (0, 1, 2) assigned to #{entries.count} entries."
  end
end

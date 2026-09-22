# frozen_string_literal: true

namespace :ai do
  desc 'Update topic polarities'
  task :set_topic_polarity, [:days] => :environment do |_task, args|
    days = args[:days].present? ? args[:days].to_i : nil

    Topic.where(status: true).find_each do |topic|
      puts topic.name
      puts '--------------------------------'

      entries =
        if days.present?
          topic.list_entries.where(published_at: days.days.ago..Time.current)
        else
          topic.list_entries.where(polarity: nil)
        end

      Parallel.each(entries, in_threads: 5) do |entry|
        entry.set_polarity(force: days.present?)
        puts entry.id
        puts entry.title
        puts entry.polarity
        puts '--------------------------------'
        sleep 1
      end
    end
  end
end

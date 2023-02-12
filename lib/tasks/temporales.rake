# frozen_string_literal: true

desc 'Update dates from datetimes'
task update_published_dates: :environment do
  Entry.where(published_date: nil).each do |entry|
    entry.update!(published_date: entry.published_at.to_date) if entry.published_at
    puts entry.published_date
  end
end

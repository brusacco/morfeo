# frozen_string_literal: true

desc 'Update stats'
task update_stats: :environment do
  Entry.where(published_at: 1.week.ago..Time.current).each do |entry|
    result = FacebookServices::UpdateStats.call(entry.id)
    entry.update!(result.data) if result.success?
    puts entry.url
    puts result.data
    puts '--------------------------------------------------------------------------'
  rescue StandardError => e
    puts "ERROR: #{e}"
    next
  end
end

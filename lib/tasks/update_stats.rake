# frozen_string_literal: true

desc 'Update stats'
task update_stats: :environment do
  Parallel.each(Entry.where(published_at: 2.week.ago..Time.current), in_threads: 4) do |entry|
    result = FacebookServices::UpdateStats.call(entry.id)
    puts result
    if result.success?
      entry.update!(result.data)
    else
      Rails.logger.error "Failed to update Facebook stats for #{entry.id}: #{result.error}"
      next
    end
  rescue StandardError => e
    Rails.logger.error "Critial Error on update Facebook stats #{e.message}"
    next
  end
end

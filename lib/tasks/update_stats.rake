# frozen_string_literal: true

desc 'Update stats'
task update_stats: :environment do
  entries = Entry.enabled.where(published_at: 5.days.ago..Time.current).order(published_at: :desc)
  count = entries.size
  
  # Reduced threads from 4 to 2 to avoid overwhelming Facebook API
  # The service now has automatic retries, so fewer concurrent requests is safer
  Parallel.each(entries, in_threads: 2) do |entry|
    result = FacebookServices::UpdateStats.call(entry.id)
    if result.success?
      puts entry.url
      puts entry.published_at
      puts result
      puts "Progress: #{count -= 1} remaining"
      puts '----------------------------------------------------'
      entry.update!(result.data)
    else
      # Only log errors that aren't timeouts (timeouts are logged by the service with retry info)
      unless result.error.to_s.include?('timeout')
        Rails.logger.error "Failed to update Facebook stats for #{entry.id}: #{result.error}"
      end
      next
    end
  rescue StandardError => e
    Rails.logger.error "Critical Error on update Facebook stats #{e.message}"
    next
  end
end

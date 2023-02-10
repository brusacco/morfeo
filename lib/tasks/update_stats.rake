# frozen_string_literal: true

desc 'Update stats'
task update_stats: :environment do
  Entry.where(published_at: 1.week.ago..Time.current).each do |entry|
    result = FacebookServices::UpdateStats.call(entry.id)
    if result.success?
      entry.update!(result.data)
    else
      Rails.logger.error "Failed to update Facebook stats for #{entry.id}: #{result.error}"
      next
    end
  end
end

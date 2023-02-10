# frozen_string_literal: true

desc 'Update Twitter stats'
task update_tw_stats: :environment do
  Entry.where(published_at: 2.weeks.ago..Time.current).each do |entry|
    result = TwitterServices::GetUrlStats.call(entry.id)
    if result.success?
      entry.update!(result.data)
    else
      Rails.logger.error "Failed to update Twitter stats for #{entry.id}: #{result.error}"
      sleep 15.minutes if result.error == 'Rate limit exceeded'
      next
    end
    puts entry.url
    puts result.data
    puts '--------------------------------------------------------------------------'
    sleep 5
  end
end

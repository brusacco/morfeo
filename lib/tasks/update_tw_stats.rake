# frozen_string_literal: true

desc 'Update Twitter stats'
task update_tw_stats: :environment do
  Entry.where(published_at: 3.days.ago..Time.current).order(published_at: :desc).each do |entry|
    result = TwitterServices::GetUrlStats.call(entry.id)
    if result.success?
      entry.update!(result.data)
      puts "Updated #{entry.url} - RT: #{result.data[:tw_rt]} - FAV: #{result.data[:tw_fav]} - TOTAL: #{result.data[:tw_total]}"
    else
      Rails.logger.error "Failed to update Twitter stats for #{entry.id}: #{result.error}"
      sleep 15.minutes if result.error == 'Rate limit exceeded'
      next
    end
    sleep 5
  end
end

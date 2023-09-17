# frozen_string_literal: true

desc 'Update Site stats'
task update_site_stats: :environment do
  Site.all.each do |site|
    puts "Start processing site #{site.name}..."
    entries = site.entries.where(published_at: 7.days.ago..)

    site.update!(
      reaction_count: entries.sum(:reaction_count),
      comment_count: entries.sum(:comment_count),
      share_count: entries.sum(:share_count),
      comment_plugin_count: entries.sum(:comment_plugin_count),
      total_count: entries.sum(:total_count),
      entries_count: entries.count
    )
  end
end

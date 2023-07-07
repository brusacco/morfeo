# frozen_string_literal: true

desc 'Update Site stats'
task update_site_stats: :environment do
  Site.all.each do |site|
    puts "Start processing site #{site.name}..."
    reaction_count = 0
    comment_count = 0
    share_count = 0
    comment_plugin_count = 0
    total_count = 0
    entries = site.entries.where(published_at: 7.day.ago..Time.current)
    entries.each do |entry|
      reaction_count += entry.reaction_count
      comment_count += entry.comment_count
      share_count += entry.share_count
      comment_plugin_count += entry.comment_plugin_count
      total_count += entry.total_count
    end

    site.update!(
      reaction_count: reaction_count,
      comment_count: comment_count,
      share_count: share_count,
      comment_plugin_count: comment_plugin_count,
      total_count: total_count,
      entries_count: entries.count
    )
  end
end

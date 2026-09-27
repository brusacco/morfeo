# frozen_string_literal: true

desc 'DEBUG: Print daily stats for the hardcoded tag "Santiago Peña" (updates nothing)'
task update_tag_stats: :environment do
  tags = Tag.where(name: 'Santiago Peña')
  tags.each do |tag|
    puts "Updating tag #{tag.name}"
    day_stats = Entry.enabled.normal_range.tagged_with(tag.name).group(:published_date).sum(:total_count)
    puts day_stats.to_json
  end
end

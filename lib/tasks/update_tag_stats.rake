# frozen_string_literal: true

desc 'Update Tag stats'
task update_tag_stats: :environment do
  tags = Tag.where(name: 'Santiago Peña')
  tags.each do |tag|
    puts "Updating tag #{tag.name}"
    day_stats = Entry.normal_range.tagged_with(tag.name).group(:published_date).sum(:total_count)
    puts day_stats.to_json
  end
end

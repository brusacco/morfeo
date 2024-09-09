# frozen_string_literal: true

desc 'Encuentra notas repetidas (mismo titulo y mismo sitio)'
task repeated_notes: :environment do
  entries = Entry.enabled.a_month_ago.where.not(title: nil).order(id: :desc).pluck(:id, :title, :url, :published_at, :site_id)
  entries.map do |entry|
    title = entry[1]
    site = entry[4]

    entries.each do |r_entry|
      #-- para que no se comparen con misma nota - ID
      next if entry[0] == r_entry[0]

      r_title = r_entry[1]
      r_site = r_entry[4]
      next unless title == r_title && site == r_site

      #-- setear como repetidas ambas notas
      entry_save = Entry.find(entry[0])
      entry_save.repeated = true
      entry_save.save

      r_entry_save = Entry.find(r_entry[0])
      r_entry_save.repeated = true
      r_entry_save.save

      puts "Title 01: #{title} - Site 01: #{site} - Entry 01: #{entry[0]}"
      puts "Title 02: #{r_title} - Site 02: #{r_site} - Entry 02: #{r_entry[0]}"
      puts '----------------------------------------------------------------------------------------------------------------------'
    end
  end
  puts 'Done!'
end

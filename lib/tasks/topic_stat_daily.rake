# frozen_string_literal: true

desc "Guardamos estadisticas diarias de topicos"
task topic_stat_daily: :environment do

  topics = Topic.where(status: true)
  var_date = 7.days.ago.to_date..Date.today
  
  topics.each do |topic|
    puts "TOPICO: #{topic.name}"
    tag_list = topic.tags.map(&:name)
    # puts "- #{tag_list}"
    
    var_date.each do |day_date|
      total_count = Entry.tagged_on_shared(tag_list, day_date)
      entry_count = Entry.tagged_on(tag_list, day_date)

      if entry_count > 0
        average = total_count / entry_count
      else
        average = 0
      end

      stat = TopicStatDaily.find_or_create_by(topic_id: topic.id, topic_date: day_date)
      stat.entry_count = entry_count
      stat.total_count = total_count
      stat.average = average
      stat.save

      puts "#{day_date} - #{entry_count} - #{total_count} - #{average}"
    end
    puts "----------------------"
  end
end
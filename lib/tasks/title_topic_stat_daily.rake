# frozen_string_literal: true

desc "Guardar valores diarios por topico - Title"
task title_topic_stat_daily: :environment do

  topics = Topic.where(status: true)
  var_date = DAYS_RANGE.days.ago.to_date..Date.today
  
  topics.each do |topic|
    puts "TOPICO: #{topic.name}"
    tag_list = topic.tags.map(&:name)
    # puts "- #{tag_list}"
    
    var_date.each do |day_date|
      entry_quantity = Entry.enabled.tagged_on_title_entry_quantity(tag_list, day_date)
      entry_interaction = Entry.enabled.tagged_on_title_entry_interaction(tag_list, day_date)

      if entry_quantity > 0
        average = entry_interaction / entry_quantity
      else
        average = 0
      end

      stat = TitleTopicStatDaily.find_or_create_by(topic_id: topic.id, topic_date: day_date)
      stat.entry_quantity = entry_quantity
      stat.entry_interaction = entry_interaction
      stat.average = average

      stat.save
      puts "#{day_date} - #{entry_quantity} - #{entry_interaction} - #{average}"
    end
    puts "--------------------------------------------------------------------------------------------------------------"
  end
end
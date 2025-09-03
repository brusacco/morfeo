# frozen_string_literal: true

desc 'Guardar valores diarios por topico'
task topic_stat_daily: :environment do
  topics = Topic.where(status: true)
  var_date = DAYS_RANGE.days.ago.to_date..Date.today

  topics.each do |topic|
    puts "TOPICO: #{topic.name}"
    tag_list = topic.tags.map(&:name)
    # puts "- #{tag_list}"

    var_date.each do |day_date|
      entry_quantity = Entry.enabled.tagged_on_entry_quantity(tag_list, day_date)
      entry_interaction = Entry.enabled.tagged_on_entry_interaction(tag_list, day_date)

      if entry_quantity > 0
        average = entry_interaction / entry_quantity
      else
        average = 0
      end

      neutral_quantity = Entry.enabled.tagged_on_neutral_quantity(tag_list, day_date)
      positive_quantity = Entry.enabled.tagged_on_positive_quantity(tag_list, day_date)
      negative_quantity = Entry.enabled.tagged_on_negative_quantity(tag_list, day_date)

      neutral_interaction = Entry.enabled.tagged_on_neutral_interaction(tag_list, day_date)
      positive_interaction = Entry.enabled.tagged_on_positive_interaction(tag_list, day_date)
      negative_interaction = Entry.enabled.tagged_on_negative_interaction(tag_list, day_date)

      stat = TopicStatDaily.find_or_create_by(topic_id: topic.id, topic_date: day_date)
      stat.entry_count = entry_quantity
      stat.total_count = entry_interaction
      stat.average = average

      stat.neutral_quantity = neutral_quantity
      stat.positive_quantity = positive_quantity
      stat.negative_quantity = negative_quantity

      stat.neutral_interaction = neutral_interaction
      stat.positive_interaction = positive_interaction
      stat.negative_interaction = negative_interaction

      stat.save
      puts "#{day_date} - #{entry_quantity} - #{entry_interaction} - #{average} | #{neutral_quantity} - #{positive_quantity} - #{negative_quantity} | #{neutral_interaction} - #{positive_interaction} - #{negative_interaction}"
    end
    puts '--------------------------------------------------------------------------------------------------------------'
  end
end

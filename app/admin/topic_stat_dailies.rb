ActiveAdmin.register TopicStatDaily do
  menu parent: "Logs", label: 'Topic Stat Daily'
  # permit_params :entry_count, :total_count, :average, :topic_date, :topic_id

  index do
    id_column
    column :topic
    column :entry_count
    column :total_count
    column :average
    column :neutral_quantity
    column :positive_quantity
    column :negative_quantity
    column :neutral_interaction
    column :positive_interaction
    column :negative_interaction
    column :topic_date
  end
end

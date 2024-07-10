ActiveAdmin.register TopicStatDaily do
  # permit_params :entry_count, :total_count, :average, :topic_date, :topic_id

  index do
    id_column
    column :topic
    column :entry_count
    column :total_count
    column :average
    column :topic_date
  end
end

# frozen_string_literal: true

ActiveAdmin.register Topic do
  permit_params :name, :positive_words, :negative_words, tag_ids: []

  filter :name

  #------------------------------------------------------------------
  #
  #------------------------------------------------------------------
  index do
    selectable_column
    id_column
    column 'Name' do |topic|
      link_to topic.name, topic_path(topic), target: :blank
    end
    column :tags
    column :created_at
    actions
  end

  show do
    attributes_table do
      row :name
      row :tags
      row :positive_words
      row :negative_words
    end
  end

  form do |f|
    f.inputs do
      f.input :name
      f.input :tags
      f.input :positive_words
      f.input :negative_words
    end
    f.actions
  end
end

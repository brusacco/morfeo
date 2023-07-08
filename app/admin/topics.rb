# frozen_string_literal: true

ActiveAdmin.register Topic do
  permit_params :name, tag_ids: []

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
    end
  end

  form do |f|
    f.inputs do
      f.input :name
      f.input :tags
    end
    f.actions
  end
end

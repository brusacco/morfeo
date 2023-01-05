# frozen_string_literal: true

ActiveAdmin.register Site do
  permit_params :name, :url, :filter

  filter :name

  index do
    selectable_column
    id_column
    column :name
    column :url
    column :filter
    actions
  end
end

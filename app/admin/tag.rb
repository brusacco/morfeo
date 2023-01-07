# frozen_string_literal: true

ActiveAdmin.register Tag do
  permit_params :name, :variations

  filter :name
  filter :variations

  index do
    selectable_column
    id_column
    column 'Name' do |tag|
      link_to tag.name, tag_path(tag), target: :blank
    end
    column :variations
    column :created_at
    column :taggings_count
    actions
  end
end

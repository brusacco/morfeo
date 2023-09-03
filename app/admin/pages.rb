# frozen_string_literal: true

ActiveAdmin.register Page do
  permit_params :uid, :name, :username, :picture, :followers, :category, :description, :website, :site_id

  filter :uid, as: :string
  filter :name, as: :string

  index do
    id_column
    column 'Image' do |page|
      image_tag(page.picture)
    end
    column :name
    column :username
    column :followers
    column :category
    column :site
    actions
  end

  form do |f|
    f.inputs 'Page' do
      f.input :uid, required: true
      f.input :site, required: true
      f.actions
    end
  end
end

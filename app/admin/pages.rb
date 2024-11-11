# frozen_string_literal: true

ActiveAdmin.register Page do
  permit_params :uid, :name, :username, :picture, :followers, :category, :description, :website, :site_id

  filter :uid, as: :string
  filter :name, as: :string

  index do
    id_column
    column 'Image' do |page|
      image_tag(page.picture || 'https://via.placeholder.com/50')
    end
    column :name
    column :username
    column :followers
    column :category
    column :site
    actions
  end

  form do |f|
    if !f.object.new_record?
      panel 'Page' do
        "<h2>#{f.object.name.to_s}</h2>".html_safe
      end
    end
    f.inputs 'Page' do
      f.input :uid, required: true
      f.input :site, required: true
      f.actions
    end
  end
end

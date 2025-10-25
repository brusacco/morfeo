# frozen_string_literal: true

ActiveAdmin.register Page do
  menu parent: 'Settings', label: 'Pages'
  permit_params :uid, :name, :username, :picture, :followers, :category, :description, :website, :site_id

  filter :uid, as: :string
  filter :name, as: :string

  index do
    id_column
    # column 'Image' do |page|
    #   image_tag(page.picture || 'default-entry.svg')
    # end

    column 'Image' do |page|
      if page.picture.present?
        image_tag page.picture
      else
        image_tag 'default-entry.svg', size: 50
      end
    end

    column :name
    column :username
    column :followers
    column :category
    column :site
    actions
  end

  form do |f|
    unless f.object.new_record?
      panel 'Page' do
        "<h2>#{f.object.name}</h2>".html_safe
      end
    end
    f.inputs 'Page' do
      f.input :uid, required: true
      f.input :site, required: true
      f.actions
    end
  end
end

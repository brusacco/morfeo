# frozen_string_literal: true

ActiveAdmin.register Site do
  permit_params :name, :url, :filter, :content_filter, :negative_filter, :page

  filter :name
  filter :url

  index do
    id_column
    column 'Image' do |site|
      if site.image64
        image_tag("data:image/jpeg;base64,#{site.image64}", size: 50)
      else
        image_tag('https://via.placeholder.com/300x300', size: 50)
      end
    end
    column :name
    column 'URL' do |site|
      link_to site.url, site.url, target: '_blank', rel: 'noopener'
    end
    column :page
    column :entries_count
    column :filter
    column :negative_filter
    column 'Content Filter' do |site|
      !site.content_filter.nil?
    end
    actions
  end

  form do |f|
    f.inputs 'Site' do
      f.input :name
      f.input :url
      f.input :filter
      f.input :content_filter
      f.input :negative_filter
      f.actions
    end
  end
end

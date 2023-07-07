# frozen_string_literal: true

ActiveAdmin.register Site do
  permit_params :name, :url, :filter, :content_filter, :negative_filter

  filter :name
  filter :url

  index do
    selectable_column
    id_column
    column :name
    column 'URL' do |site|
      link_to site.url, site.url, target: '_blank', rel: 'noopener'
    end
    column :entries_count
    column :filter
    column :negative_filter
    column 'Content Filter' do |site|
      !site.content_filter.nil?
    end
    actions
  end
end

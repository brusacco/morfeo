# frozen_string_literal: true

ActiveAdmin.register Site do
  menu parent: 'Settings', label: 'Digital Profiles'
  permit_params :name, :url, :filter, :content_filter, :negative_filter, :page, :status, :is_js

  filter :name
  filter :url
  filter :status, label: 'Estado'
  filter :is_js, label: 'Medios JS'

  scope 'Todos', :all, default: :true
  scope 'Activos', :enabled
  scope 'Inactivos', :disabled
  scope 'Medios JS', :js_site
  scope 'Sin Notas', :entry_none

  index do
    id_column
    column :name
    column 'Estado' do |site|
      site.status
    end
    column 'URL' do |site|
      link_to site.url, site.url, target: '_blank', rel: 'noopener'
    end
    column :page
    column :twitter_profile
    column :entries_count
    column :filter
    column :negative_filter
    column 'Content Filter' do |site|
      !site.content_filter.nil?
    end
    column 'Medio JS?' do |site|
      site.is_js
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
      f.input :status, label: 'Estado'
      f.input :is_js, label: 'Es un Medio JS?'
      f.actions
    end
  end
end

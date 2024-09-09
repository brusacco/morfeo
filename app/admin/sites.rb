# frozen_string_literal: true

ActiveAdmin.register Site do
  permit_params :name, :url, :filter, :content_filter, :negative_filter, :page, :status

  filter :name
  filter :url
  filter :status, label: 'Estado'

  scope 'Todos', :all, default: :true
  scope 'Activos', :enabled
  scope 'Inactivos', :disabled

  index do
    id_column
    column :name
		column 'Estado'do |site|
			site.status
		end
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
      f.input :status, label: 'Estado'
      f.actions
    end
  end
end

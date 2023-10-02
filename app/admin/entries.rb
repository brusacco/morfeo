# frozen_string_literal: true

ActiveAdmin.register Entry do
  config.sort_order = 'published_at_desc'
  permit_params :url, :title, :enabled

  scoped_collection_action :scoped_collection_destroy

  filter :site, collection: proc { Site.order(:name) }
  filter :url
  filter :title
  filter :published_at
  filter :enabled

  scope 'Null Date' do |entry|
    entry.where(published_at: nil)
  end

  index do
    selectable_column
    id_column
    column :title
    column :total_count
    column :site
    column :tag_list
    column 'Url' do |entry|
      link_to entry.url, entry.url, target: :blank
    end
    column :published_at
    column 'Image' do |entry|
      if entry.image_url.present?
        image_tag entry.image_url, size: 32
      else
        image_tag 'https://via.placeholder.com/32', size: 32
      end
    end
    actions
  end
end

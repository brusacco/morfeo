# frozen_string_literal: true

ActiveAdmin.register Entry do
  config.sort_order = 'published_at_desc'
  permit_params :url, :title, :enabled, :repeated

  scoped_collection_action :scoped_collection_destroy

  scoped_collection_action :scoped_collection_update, title: 'Actualizaciones Rapidas', form: -> do 
    { 
      notas_Repetidas: [['Hecho. Quitar del listado', 2], ['No es nota repetida', 0]],
      habilitar_Deshabilitar_Notas: [['Habilitar', true], ['Deshabilitar', false]]
    }
  end

  filter :site, collection: proc { Site.order(:name) }
  filter :url
  filter :title
  filter :published_at, label: 'Fecha'
  filter :enabled, label: 'Habilitado'
  filter :repeated, label: 'Repetido', as: :select, collection: Entry.repeateds

  scope :todos, :all, default: :true
  scope :habilitados, :enabled
  scope :deshabilitados, :disabled
  scope :repetidos do |entry|
    entry.where(repeated: 1)
  end
  scope :limpiados do |entry|
    entry.where(repeated: 2)
  end  
  scope 'Null Date' do |entry|
    entry.where(published_at: nil)
  end

  form do |f|
    f.inputs 'Nota' do
      f.input :url
      f.input :title
      f.input :repeated, label: 'Repetido', as: :select, collection: Entry.repeateds
      f.input :enabled, label: 'Habilitado?'
    end
    f.actions
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
    column 'Habilitado', &:enabled

    column 'Repetido', sortable: :repeated do |e|
      if e.repeated == 0
        status_tag(Entry.repeateds.key(e.repeated), class: 'ok')
      elsif e.repeated == 2
        status_tag(Entry.repeateds.key(e.repeated), class: 'warning')
      elsif e.repeated == 1
        status_tag(Entry.repeateds.key(e.repeated), class: 'error')
      end
    end

    column 'Image' do |entry|
      if entry.image_url.present?
        image_tag entry.image_url, size: 32
      else
        image_tag 'default-entry.svg', size: 32
      end
    end
    actions
  end
end

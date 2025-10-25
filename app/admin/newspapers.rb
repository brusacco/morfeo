ActiveAdmin.register Newspaper do
  menu parent: 'Settings', label: 'Newspapers'
  filter :date, label: 'Fecha'
  filter :site_id, label: 'Medio', as: :select, collection: Site.all.map { |u| [u.name, u.id] }, include_blank: true

  permit_params :date, :site_id, :cover, :backcover, newspaper_texts_attributes: %i[id title description _destroy]
  form do |f|
    f.inputs 'Archivos' do
      f.input :site_id,
              label: 'Medio',
              as: :select,
              collection: Site.all.map { |t|
                [t.name, t.id]
              },
              input_html: { required: true }
      f.input :cover, as: :file, label: 'Tapa'
      f.input :backcover, as: :file, label: 'Contra Tapa'
      f.input :date, label: 'Fecha', input_html: { value: f.object.date || Date.today, required: true }
    end

    f.inputs 'Textos' do
      f.has_many :newspaper_texts, new_record: 'Añadir Título y/o Descripción', allow_destroy: true do |t|
        t.input :title, label: 'Título'
        t.input :description, label: 'Descripción'
      end
    end

    f.actions
  end

  index do
    selectable_column
    column 'Fecha', &:date

    column 'Tapa' do |file|
      link_to image_tag(file.cover, width: 150), admin_newspaper_path(file) if file.cover.present?
    end

    column 'Contra Tapa' do |file|
      link_to image_tag(file.backcover, width: 150), admin_newspaper_path(file) if file.backcover.present?
    end

    column 'Medio', &:site

    column 'Titulares' do |t|
      li t.newspaper_texts.map(&:title).join('<li>').html_safe if t.newspaper_texts.present?
    end

    actions dropdown: true
  end

  show do |_cover|
    attributes_table do
      row 'Fecha', &:date
      row 'Medio', &:site

      row 'Tapa' do |file|
        image_tag(file.cover, width: 250) if file.cover.present?
      end

      row 'Contra Tapa' do |file|
        image_tag(file.backcover, width: 250) if file.backcover.present?
      end

      row 'Titulares' do |t|
        ul do
          li t.newspaper_texts.map(&:title).join('<li>').html_safe if t.newspaper_texts.present?
        end
      end

      row 'Descripciones' do |t|
        ul do
          li t.newspaper_texts.map(&:description).join('<li>').html_safe if t.newspaper_texts.present?
        end
      end
    end
  end
end

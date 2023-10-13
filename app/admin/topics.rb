# frozen_string_literal: true

ActiveAdmin.register Topic do
  permit_params :name, :positive_words, :negative_words, tag_ids: [], user_ids: []

  filter :name

  #------------------------------------------------------------------
  #
  #------------------------------------------------------------------
  index do
    selectable_column
    id_column
    column 'Name' do |topic|
      link_to topic.name, topic_path(topic), target: :blank
    end
    column :tags

    column "Usuario(s) asignado(s)" do |topic|
      topic.users.map { |user| link_to user.name, admin_user_path(user) }.join('<br />').html_safe
    end    

    column :created_at
    actions
  end

  show do
    attributes_table do
      row :name
      row :tags
      row :positive_words
      row :negative_words

      row "Usuario(s) asignado(s)" do 
        topic.users.map { |user| link_to user.name, admin_user_path(user) }.join('<br />').html_safe
      end      
    end
  end

  form html: { enctype: 'multipart/form-data', multipart: true } do |f|
    columns do
      column do    
        f.inputs 'Crear Tópico', multipart: :true do
          f.input :name
          f.input :tags
          f.input :positive_words
          f.input :negative_words
        end
      end

      column do
        f.inputs "Lista de Usuarios", multipart: :true do
          f.input :users, label:'Asiganar a:', as: :check_boxes, :collection => User.all.collect {|user| [user.name, user.id]}
        end
      end
    end      

    f.actions
  end
end

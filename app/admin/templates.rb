ActiveAdmin.register Template do
  permit_params :topic_id, :title, :sumary, :date, :admin_user_id
  actions :all, except: :destroy

  action_item :reporte, only: [:show, :edit] do
    link_to 'Reporte PDF', template_path, target: :blank
  end

  controller do
    def create
      params[:template][:admin_user_id] = current_admin_user.id
      super
    end

    def update
      # params[:template].delete(:admin_user_id) if params[:template][:admin_user_id].present?
      params[:template][:admin_user_id] = current_admin_user.id
      super
    end
  end

  form do |f|
    f.inputs do
      f.input :topic, label: 'Topico'
      f.input :title, label: 'Titulo'
      f.input :sumary, label: 'Resumen'
      f.input :date, label: 'Fecha', input_html: { value: Date.today }, as: :hidden
      f.input :admin_user_id, as: :hidden, input_html: { value: current_admin_user.id }
    end
    f.actions
  end


  index do
    id_column
    column 'Topico', :topic
    column 'Titulo', :title
    column 'Resumen', :sumary
    column 'Fecha', :date
    column 'Creado por', :admin_user
    column 'Fecha de Creacion', :created_at
    actions
  end 
end
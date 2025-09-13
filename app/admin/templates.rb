ActiveAdmin.register Template do
  permit_params :topic_id, :title, :sumary, :start_date, :end_date, :admin_user_id
  actions :all, except: :destroy

  action_item :reporte, only: [:show, :edit] do
    link_to 'Reporte PDF', template_path(start_date: template.start_date, end_date: template.end_date), target: :blank
  end

  controller do
    def create
      params[:template][:admin_user_id] = current_admin_user.id
      super
    end

    def update
      params[:template][:admin_user_id] = current_admin_user.id
      super
    end
  end

  form do |f|
    f.inputs do
      f.input :topic, label: 'Topico'
      f.input :title, label: 'Titulo'
      f.input :sumary, label: 'Resumen'
      f.input :start_date, label: 'Fecha desde', input_html: { placeholder: DAYS_RANGE.days.ago.strftime('%d/%m/%Y') }
      f.input :end_date, label: 'Fecha hasta', input_html: { placeholder: Date.today }
      f.input :admin_user_id, as: :hidden, input_html: { value: current_admin_user.id }
    end
    f.actions
  end

  index do
    id_column
    column 'Topico', :topic
    column 'Titulo', :title
    column 'Resumen', :sumary
    column 'Fecha desde', :start_date
    column 'Fecha hasta', :end_date
    column 'Creado por', :admin_user
    column 'Fecha de Creacion', :created_at
    actions
  end
end

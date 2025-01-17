class TemplatesController < ApplicationController
  before_action :authenticate_user!
  before_action :set_template, only: %i[show pdf_report]

  def index
    @templates = Template.order(created_at: :desc)
  end

  def new
    @template = Template.new
  end

  def create
    template = Template.new(template_params)
    if template.save
      redirect_to template_path(template, format: :pdf)
    else
      Rails.logger.info(template.errors.inspect)
      flash[:alert] = "Error al intentar crear el reporte."
      render :new
    end
  end

  def show
    @topic = @template.topic
    @entries = @topic.list_entries
    @chart_entries = @entries.group_by_day(:published_at)

    respond_to do |format|
      format.html
      format.pdf do
        render pdf: "#{@template.title}-#{@template.date.strftime('%Y%m%d')}",
               layout: 'pdf',
               template: "templates/pdf_report",
               formats: [:html],
               javascript_delay: 5000,
               disposition: :inline,
               orientation: 'Portrait',
               print_media_type: true,
               header: { right: '[page] de [topage]' }
      end
      
    end
  end

  def pdf_report; end

  private

  def template_params
    params.require(:template).permit(:topic_id, :title, :sumary, :date)
  end

  def set_template
    @template = Template.find(params[:id])
  rescue ActiveRecord::RecordNotFound
    redirect_to templates_path, alert: 'Reporte no encontrado'
  end
end

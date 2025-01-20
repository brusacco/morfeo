# require 'grover'

class TemplatesController < ApplicationController
  before_action :authenticate_user!

  def index
    @templates = Template.order(created_at: :desc)
  end

  def new
    @template = Template.new
  end

  def create
    template = Template.new(template_params)
    if template.save
      # redirect_to template_path(template, format: :pdf)
      redirect_to template_path(template)
    else
      Rails.logger.info(template.errors.inspect)
      flash[:alert] = "Error al intentar crear el reporte."
      render :new
    end
  end
 
  def show
    begin
      @template = Template.find(params[:id])
      @topic = @template.topic
      @entries = @topic.list_entries
      @chart_entries = @entries.group_by_day(:published_at)

    rescue => exception
      Rails.logger.error(exception.message)
      redirect_to templates_path, alert: 'Reporte no encontrado'
    end
    render layout: 'reporte'
  end

  # def pdf_report
  #   @template = Template.find(params[:id])
  #   @topic = @template.topic
  #   @entries = @topic.list_entries
  #   @chart_entries = @entries.group_by_day(:published_at)

  #   respond_to do |format|
  #     format.html
  #     format.pdf do
  #       html = render_to_string(
  #         template: "templates/pdf_report",
  #         layout: "pdf",
  #         formats: [:html]
  #       )
  #       pdf = Grover.new(html).to_pdf
  #       # pdf = Grover.new(html, format: 'A4', display_url: browser_endpoint).to_pdf

  #       # pdf = Grover.new(html, options: { debug: true }).to_pdf
  #       # pdf = Grover.new(html, options: {
  #       #   wait_until: 'networkidle0', # Espera hasta que no haya solicitudes de red activas
  #       #   convert_timeout: 100000 # Extiende el tiempo de conversión
  #       # }).to_pdf
        
  #       # pdf = Grover.new(html, format: 'A4', display_url: 'http://localhost:3000', options: { launch_args: ['--no-sandbox'] }).to_pdf

  #       send_data pdf,
  #                 filename: "#{@template.topic.name}_#{@template.title}.pdf",
  #                 type: "application/pdf",
  #                 disposition: "inline"
  #     end 
  # end

  private 

  # def browser_endpoint
  #   if Rails.env.production?
  #     "https://morfeo.com.py"
  #   else 
  #     "http://localhost:6500"
  #   end
  # end 

  def template_params
    params.require(:template).permit(:topic_id, :title, :sumary, :date)
  end
end

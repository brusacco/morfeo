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
      topic = @template.topic
      @entries = topic.report_entries
      @chart_entries = @entries.group_by_day(:published_at)

      @top_entries = @entries.limit(15)

      polarity_counts = @entries.group(:polarity).count
      @neutrals = polarity_counts['neutral'] || 0
      @positives = polarity_counts['positive'] || 0
      @negatives = polarity_counts['negative'] || 0 

      if @entries.any?
        @percentage_neutrals = (Float(@neutrals) / @entries.size * 100).round(0)
        @percentage_positives = (Float(@positives) / @entries.size * 100).round(0)
        @percentage_negatives = (Float(@negatives) / @entries.size * 100).round(0)
  
        # total_count = @entries.size + @all_entries_size
        # @topic_percentage = (Float(@entries.size) / total_count * 100).round(0)
        # @all_percentage = (Float(@all_entries_size) / total_count * 100).round(0)
  
        # total_count = @entries.sum(:total_count) + @all_entries_interactions
        # @topic_interactions_percentage = (Float(@entries.sum(&:total_count)) / total_count * 100).round(1)
        # @all_intereactions_percentage = (Float(@all_entries_interactions) / total_count * 100).round(1)
      end
      
      polarities_entries_counts = @entries.where.not(polarity: nil).group(:polarity).count('*').sort_by { |key, _value| key }.to_h
      polarity_entries_total_count = polarities_entries_counts.values.sum.to_f
      @polarities_entries_percentages = polarities_entries_counts.transform_values { |count| (count / polarity_entries_total_count * 100).round(0) }

      polarities_interactions_counts = @entries.where.not(polarity: nil).group(:polarity).sum('total_count').sort_by { |key, _value| key }.to_h
      polarities_interactions_total_count = polarities_interactions_counts.values.sum.to_f
      @polarities_interactions_percentages = polarities_interactions_counts.transform_values { |count| (count / polarities_interactions_total_count * 100).round(0) }

      # @demo_entries = {
      #   "Negativas" => 68,
      #   "Neutras" => 30,
      #   "Positivas" => 2
      # }

      # @demo_interactions = {
      #   "Negativas" => 8,
      #   "Neutras" => 20,
      #   "Positivas" => 72
      # }     

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

  def template_params
    params.require(:template).permit(:topic_id, :title, :sumary, :date)
  end

  # def browser_endpoint
  #   if Rails.env.production?
  #     "https://morfeo.com.py"
  #   else 
  #     "http://localhost:6500"
  #   end
  # end  
end

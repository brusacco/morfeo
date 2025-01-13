class ReportsController < ApplicationController
  before_action :authenticate_user!
  
  def index
    @reports = Report.all.order(created_at: :desc)
  end

  def new
    @report = Report.new
  end
  

  def create
    report = Report.new(report_params)

    if report.save
      redirect_to report_path(report, format: :pdf)
      # redirect_to reports_path, notice: "Reporte Creado!"
    else
      Rails.logger.info(report.errors.inspect)
      render :new, alert: "Error al intentar crear reporte"
    end

  end
  

  def show
    begin
      @report = Report.find(params[:id])
      
      respond_to do |format|
        format.html
        format.pdf do
          render pdf: [@report.id, @report.title].join(' - '),
          template: "reports/pdf_report",
          formats: [:html],
          disposition: :inline,
          layout: 'pdf',
          orientation: :Portrait # default Portrait - Landscape
        end
      end

    rescue => exception
      redirect_to(reports_path, alert: 'Reporte no encontrado')
    end 
  end

  def pdf_report
    begin
      @report = Report.find(params[:id])
      respond_to do |format|
        format.pdf do
          render pdf: [@report.id, @report.title].join(' - '),
          template: "reports/pdf_report",
          formats: [:html],
          disposition: :inline,
          layout: 'pdf',
          orientation: :Portrait # default Portrait - Landscape
        end
      end
    rescue => exception
      redirect_to(reports_path, alert: 'Reporte no encontrado')
    end     
  end
  

  private

  def report_params
    params.require(:report).permit(:topic_id, :report_text, :title, :sumary, :date)
  end 
end

ActiveAdmin.register Report do
  permit_params :topic_id, :report_text, :title, :sumary, :date

  member_action :generate_pdf, method: :get do
    report = Report.find(params[:id])
    pdf_html = render_to_string(
      pdf: "reporte_#{report.id}",
      template: 'admin/reports/generate_pdf.html.erb',
      layout: 'pdf'
    )
    send_data pdf_html, filename: "reporte_#{report.title.parameterize}.pdf", type: 'application/pdf', disposition: 'attachment'
  end

  action_item :generate_pdf, only: :show do
    link_to 'Generate PDF', generate_pdf_admin_report_path(resource), method: :get
  end
end

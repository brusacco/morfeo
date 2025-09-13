class TemplatesController < ApplicationController
  before_action :authenticate_admin_user!

  def show
    begin
      @template = Template.find(params[:id])
      topic = @template.topic

      filter_start_date = params[:start_date]
      filter_end_date = params[:end_date]

      # si no se completa ninguna fecha, toma del dia actual a una semana atras
      if !filter_start_date.present? && !filter_end_date.present?
        start_date = DAYS_RANGE.days.ago
        end_date = Date.today
      # si se completa solo la FECHA DESDE, toma la FECHA HASTA del dia actual
      elsif filter_start_date.present? && !filter_end_date.present?
        start_date = Date.parse(filter_start_date)
        end_date = Date.today
      # si se completan ambas fechas, normal
      else
        start_date = Date.parse(filter_start_date)
        end_date = Date.parse(filter_end_date)
      end

      @entries = topic.report_entries(start_date, end_date)
      @top_entries = @entries.limit(25)

      @chart_entries = @entries.group_by_day(:published_at)
      @total_entries = @entries.size
      @total_interactions = @entries.sum(&:total_count)

      @title_entries = topic.report_title_entries(start_date, end_date)
      @title_top_entries = @title_entries.limit(15)

      if @total_entries.zero?
        @promedio = 0
      else
        @promedio = @total_interactions / @total_entries
      end

      polarity_counts = @entries.group(:polarity).count
      @neutrals = polarity_counts['neutral'] || 0
      @positives = polarity_counts['positive'] || 0
      @negatives = polarity_counts['negative'] || 0

      # Medios
      @top_sites = @entries.group("sites.name").count('*').sort_by { |_, v| -v }
                           .first(3)
      @top_sites_interactions = @entries.group("sites.name").sum(:total_count).sort_by { |_, v| -v }
                                        .first(3)

      # Impacto del Topico
      @other_entries_size = Entry.enabled.normal_range.where.not(id: @entries.ids).count
      @other_entries_interactions = Entry.enabled.normal_range.where.not(id: @entries.ids).sum(:total_count)

      if @entries.any?
        @percentage_neutrals = (Float(@neutrals) / @entries.size * 100).round(0)
        @percentage_positives = (Float(@positives) / @entries.size * 100).round(0)
        @percentage_negatives = (Float(@negatives) / @entries.size * 100).round(0)

        total_entries_count = @entries.size + @other_entries_size
        @topic_entries_percentage = (Float(@entries.size) / total_entries_count * 100).round(0)
        @all_entries_percentage = (Float(@other_entries_size) / total_entries_count * 100).round(0)

        total_interactions_count = @entries.sum(:total_count) + @other_entries_interactions
        @topic_interactions_percentage = (Float(@entries.sum(&:total_count)) / total_interactions_count * 100).round(1)
        @all_intereactions_percentage = (Float(@other_entries_interactions) / total_interactions_count * 100).round(1)
      end

      polarities_entries_counts = @entries.where.not(polarity: nil).group(:polarity).count('*').sort_by { |key, _value|
        key
      }
.to_h
      polarity_entries_total_count = polarities_entries_counts.values.sum.to_f
      @polarities_entries_percentages =
        polarities_entries_counts.transform_values { |count|
          (count / polarity_entries_total_count * 100).round(0)
        }

      polarities_interactions_counts = @entries.where.not(polarity: nil).group(:polarity).sum('total_count').sort_by { |key, _value|
        key
      }
.to_h
      polarities_interactions_total_count = polarities_interactions_counts.values.sum.to_f
      @polarities_interactions_percentages =
        polarities_interactions_counts.transform_values { |count|
          (count / polarities_interactions_total_count * 100).round(0)
        }

      @interacciones_ultimo_dia_topico = Topic.joins(:topic_stat_dailies)
                                              .where(topic_stat_dailies: { topic_date: 1.day.ago.. })
                                              .group('topics.name').order('sum_topic_stat_dailies_total_count DESC').limit(10)
                                              .sum('topic_stat_dailies.total_count')

      @notas_ultimo_dia_topico = Topic.joins(:topic_stat_dailies)
                                      .where(topic_stat_dailies: { topic_date: 1.day.ago.. })
                                      .group('topics.name').order('sum_topic_stat_dailies_entry_count DESC').limit(10)
                                      .sum('topic_stat_dailies.entry_count')

      @ai_reports = topic.reports.where.not(report_text: nil).where.not(created_at: Time.zone.now.beginning_of_day..Time.zone.now.end_of_day).order(created_at: :desc).limit(10)

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

      render layout: 'reporte'
    rescue => exception
      Rails.logger.error(exception.message)
      redirect_to root_path, alert: 'Reporte no encontrado'
    end
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

  # private

  # def browser_endpoint
  #   if Rails.env.production?
  #     "https://morfeo.com.py"
  #   else
  #     "http://localhost:6500"
  #   end
  # end
end

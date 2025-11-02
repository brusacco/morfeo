# frozen_string_literal: true

# Professional General Dashboard Controller
# CEO-level reporting and analytics across all data sources
class GeneralDashboardController < ApplicationController
  include TopicAuthorizable
  
  before_action :authenticate_user!
  before_action :set_topic
  before_action :authorize_topic_access!, only: [:show, :pdf]

  caches_action :show, :pdf, expires_in: 30.minutes,
                cache_path: proc { |c| { topic_id: c.params[:id], user_id: c.current_user.id } }

  def show
    @start_date = start_date
    @end_date = end_date
    
    @dashboard_data = GeneralDashboardServices::AggregatorService.call(
      topic: @topic,
      start_date: @start_date,
      end_date: @end_date
    )
    
    # Extract data for easy view access
    @executive_summary = @dashboard_data[:executive_summary]
    @channel_performance = @dashboard_data[:channel_performance]
    @temporal_intelligence = @dashboard_data[:temporal_intelligence]
    @sentiment_analysis = @dashboard_data[:sentiment_analysis]
    @reach_analysis = @dashboard_data[:reach_analysis]
    @competitive_analysis = @dashboard_data[:competitive_analysis]
    @top_content = @dashboard_data[:top_content]
    @word_analysis = @dashboard_data[:word_analysis]
    @recommendations = @dashboard_data[:recommendations]
    
    # Prepare chart data
    prepare_chart_data
  end

  def pdf
    @start_date = start_date
    @end_date = end_date
    
    @dashboard_data = GeneralDashboardServices::AggregatorService.call(
      topic: @topic,
      start_date: @start_date,
      end_date: @end_date
    )
    
    # Extract data for easy view access
    @executive_summary = @dashboard_data[:executive_summary]
    @channel_performance = @dashboard_data[:channel_performance]
    @temporal_intelligence = @dashboard_data[:temporal_intelligence]
    @sentiment_analysis = @dashboard_data[:sentiment_analysis]
    @reach_analysis = @dashboard_data[:reach_analysis]
    @competitive_analysis = @dashboard_data[:competitive_analysis]
    @top_content = @dashboard_data[:top_content]
    @word_analysis = @dashboard_data[:word_analysis]
    @recommendations = @dashboard_data[:recommendations]
    
    # Prepare chart data
    prepare_chart_data
    
    render layout: false
  rescue StandardError => e
    # Log full error details
    Rails.logger.error "Error generating PDF for topic #{@topic.id}: #{e.class} - #{e.message}"
    Rails.logger.error e.backtrace.first(10).join("\n")
    
    # Show simple error page that prints
    render html: <<~HTML.html_safe, layout: false
      <!DOCTYPE html>
      <html>
        <head>
          <meta charset="utf-8">
          <title>Error - PDF</title>
        </head>
        <body style="font-family: Arial; padding: 40px; text-align: center;">
          <h1>Error generando el PDF</h1>
          <p>Ha ocurrido un error al generar el reporte. Por favor contacte al administrador.</p>
          <p style="color: #666; font-size: 12px;">Error ID: #{Time.now.to_i}</p>
          <script>setTimeout(function(){ window.close(); }, 3000);</script>
        </body>
      </html>
    HTML
  end

  private

  def set_topic
    @topic = Topic.find(params[:id])
  end

  def start_date
    if params[:start_date].present?
      Date.parse(params[:start_date]).beginning_of_day
    else
      DAYS_RANGE.days.ago.beginning_of_day
    end
  rescue ArgumentError
    DAYS_RANGE.days.ago.beginning_of_day
  end

  def end_date
    if params[:end_date].present?
      Date.parse(params[:end_date]).end_of_day
    else
      Time.zone.now.end_of_day
    end
  rescue ArgumentError
    Time.zone.now.end_of_day
  end

  def prepare_chart_data
    # Channel comparison chart
    @chart_channel_mentions = {
      'Digital' => @channel_performance[:digital][:mentions],
      'Facebook' => @channel_performance[:facebook][:mentions],
      'Twitter' => @channel_performance[:twitter][:mentions]
    }
    
    @chart_channel_interactions = {
      'Digital' => @channel_performance[:digital][:interactions],
      'Facebook' => @channel_performance[:facebook][:interactions],
      'Twitter' => @channel_performance[:twitter][:interactions]
    }
    
    @chart_channel_reach = {
      'Digital' => @channel_performance[:digital][:reach],
      'Facebook' => @channel_performance[:facebook][:reach],
      'Twitter' => @channel_performance[:twitter][:reach]
    }
    
    # Sentiment distribution
    @chart_sentiment_distribution = {
      'Positivo' => @sentiment_analysis[:overall][:distribution][:positive],
      'Neutral' => @sentiment_analysis[:overall][:distribution][:neutral],
      'Negativo' => @sentiment_analysis[:overall][:distribution][:negative]
    }
    
    # Share of voice
    @chart_share_of_voice = {
      @topic.name => @competitive_analysis[:share_of_voice],
      'Otros Tópicos' => (100 - @competitive_analysis[:share_of_voice])
    }
  end
end


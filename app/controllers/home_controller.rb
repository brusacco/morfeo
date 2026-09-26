# frozen_string_literal: true

class HomeController < ApplicationController
  before_action :authenticate_user!, except: %i[deploy check]
  # Only skip CSRF for webhook endpoints (deploy, check)
  skip_before_action :verify_authenticity_token, only: %i[deploy check]

  def index
    # NEW: Phase 1 & 2 - Executive Dashboard Data
    dashboard_data = HomeServices::DashboardAggregatorService.call(topics: @topicos, days_range: DAYS_RANGE)

    # Phase 1: Executive Summary
    @executive_summary = dashboard_data[:executive_summary]

    # Channel Performance
    @channel_stats = dashboard_data[:channel_stats]

    # Topic Statistics
    @topic_stats = dashboard_data[:topic_stats]
    @topic_trends = dashboard_data[:topic_trends]
    @topic_chart_series = dashboard_data[:topic_chart_series]
    @daily_topic_rankings = dashboard_data[:daily_topic_rankings]

    # Alerts
    @alerts = dashboard_data[:alerts]

    # Tags Cloud is calculated inside the cached dashboard payload.
    @word_occurrences = dashboard_data[:word_occurrences]

    # Top Content
    @top_content = dashboard_data[:top_content]

    # Phase 2: Enhanced Analytics
    @sentiment_intelligence = dashboard_data[:sentiment_intelligence]
    @temporal_intelligence = dashboard_data[:temporal_intelligence]
    @competitive_intelligence = dashboard_data[:competitive_intelligence]

    # Chart data for channel comparison
    @chart_channel_mentions = {
      'Digital' => @channel_stats[:digital][:mentions],
      'Facebook' => @channel_stats[:facebook][:mentions],
      'Twitter' => @channel_stats[:twitter][:mentions],
      'Instagram' => @channel_stats[:instagram][:mentions]
    }

    @chart_channel_interactions = {
      'Digital' => @channel_stats[:digital][:interactions],
      'Facebook' => @channel_stats[:facebook][:interactions],
      'Twitter' => @channel_stats[:twitter][:interactions],
      'Instagram' => @channel_stats[:instagram][:interactions]
    }

    @chart_channel_reach = {
      'Digital' => @channel_stats[:digital][:reach],
      'Facebook' => @channel_stats[:facebook][:reach],
      'Twitter' => @channel_stats[:twitter][:reach]
    }

    # EXISTING: Multiple Charts (kept for backward compatibility)
    @entry_quantities = build_topic_chart_series(:entry_quantities)
    @entry_interactions = build_topic_chart_series(:entry_interactions)
    @neutral_quantity = build_topic_chart_series(:neutral_quantity)
    @positive_quantity = build_topic_chart_series(:positive_quantity)
    @negative_quantity = build_topic_chart_series(:negative_quantity)

    @interacciones_ultimo_dia_topico = @daily_topic_rankings[:interactions]
    @notas_ultimo_dia_topico = @daily_topic_rankings[:entries]

    @positive_words = @topicos.all.map(&:positive_words).flatten.join(',')
    @negative_words = @topicos.all.map(&:negative_words).flatten.join(',')

    # Tapa y Contra Tapa de Diarios
    @newspapers = Newspaper.where(date: Date.today)
  end

  def deploy
    Dir.chdir('/home/rails/morfeo') do
      system('export RAILS_ENV=production')

      # Check out the latest code from the Git repository
      system('git pull')

      # Install dependencies
      system('RAILS_ENV=production bundle install')

      # Migrate the database
      system('RAILS_ENV=production rails db:migrate')

      # Precompile assets
      system('RAILS_ENV=production rake assets:precompile')

      # Clear Rails cache to see changes immediately
      # system('RAILS_ENV=production rails cache:clear')

      # Restart the Puma server
      system('touch tmp/restart.txt')

      # Update cron jobs
      system('whenever -i')

      # Warm the dashboards
      # system('RAILS_ENV=production rails cache:warm_dashboards')
    end

    render plain: 'Deployment complete!'
  end

  def check
    @url = params[:url]
    @doc = Nokogiri::HTML(URI.parse(@url).open('User-Agent' => 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/92.0.4515.159 Safari/537.36'))
    @result = WebExtractorServices::ExtractDate.call(@doc)
    render layout: false
  end

  private

  def build_topic_chart_series(metric)
    return [] if @topic_chart_series.blank?

    @topicos.map do |topic|
      topic_series = @topic_chart_series[topic.id] || {}

      {
        name: topic.name,
        topicId: topic.id,
        data: topic_series[metric] || {}
      }
    end
  end
end

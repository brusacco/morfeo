# frozen_string_literal: true

class HomeController < ApplicationController
  caches_action :index, expires_in: 30.minutes,
                cache_path: proc { |c| { user_id: c.current_user&.id } }
  before_action :authenticate_user!, except: %i[deploy check]
  skip_before_action :verify_authenticity_token

  def index
    # NEW: Phase 1 & 2 - Executive Dashboard Data
    dashboard_data = HomeServices::DashboardAggregatorService.call(
      topics: @topicos,
      days_range: DAYS_RANGE
    )

    # Phase 1: Executive Summary
    @executive_summary = dashboard_data[:executive_summary]
    
    # Channel Performance
    @channel_stats = dashboard_data[:channel_stats]
    
    # Topic Statistics
    @topic_stats = dashboard_data[:topic_stats]
    @topic_trends = dashboard_data[:topic_trends]
    
    # Alerts
    @alerts = dashboard_data[:alerts]
    
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
      'Twitter' => @channel_stats[:twitter][:mentions]
    }

    @chart_channel_interactions = {
      'Digital' => @channel_stats[:digital][:interactions],
      'Facebook' => @channel_stats[:facebook][:interactions],
      'Twitter' => @channel_stats[:twitter][:interactions]
    }

    @chart_channel_reach = {
      'Digital' => @channel_stats[:digital][:reach],
      'Facebook' => @channel_stats[:facebook][:reach],
      'Twitter' => @channel_stats[:twitter][:reach]
    }

    # EXISTING: Multiple Charts (kept for backward compatibility)
    @entry_quantities =
      @topicos.map do |topic|
        {
          name: topic.name,
          topicId: topic.id,
          data: topic.topic_stat_dailies.normal_range.group_by_day(:topic_date).sum(:entry_count)
        }
      end

    @entry_interactions =
      @topicos.map do |topic|
        {
          name: topic.name,
          topicId: topic.id,
          data: topic.topic_stat_dailies.normal_range.group_by_day(:topic_date).sum(:total_count)
        }
      end

    @neutral_quantity =
      @topicos.map do |topic|
        {
          name: topic.name,
          topicId: topic.id,
          data: topic.topic_stat_dailies.normal_range.group_by_day(:topic_date).sum(:neutral_quantity)
        }
      end

    @positive_quantity =
      @topicos.map do |topic|
        {
          name: topic.name,
          topicId: topic.id,
          data: topic.topic_stat_dailies.normal_range.group_by_day(:topic_date).sum(:positive_quantity)
        }
      end

    @negative_quantity =
      @topicos.map do |topic|
        {
          name: topic.name,
          topicId: topic.id,
          data: topic.topic_stat_dailies.normal_range.group_by_day(:topic_date).sum(:negative_quantity)
        }
      end

    @interacciones_ultimo_dia_topico = @topicos.joins(:topic_stat_dailies)
                                               .where(topic_stat_dailies: { topic_date: 1.day.ago.. })
                                               .group('topics.name').order('sum_topic_stat_dailies_total_count DESC').limit(10)
                                               .sum('topic_stat_dailies.total_count')

    @notas_ultimo_dia_topico = @topicos.joins(:topic_stat_dailies)
                                       .where(topic_stat_dailies: { topic_date: 1.day.ago.. })
                                       .group('topics.name').order('sum_topic_stat_dailies_entry_count DESC').limit(10)
                                       .sum('topic_stat_dailies.entry_count')

    # Tags Cloud - Using direct associations for optimal performance
    # Single query instead of N+1 (one query per topic)
    if ENV['USE_DIRECT_ENTRY_TOPICS'] == 'true'
      # NEW: Use direct associations (single query for all topics)
      combined_entries = Entry.joins(:entry_topics, :site)
                              .where(entry_topics: { topic_id: @topicos.pluck(:id) })
                              .where(published_at: DAYS_RANGE.days.ago.beginning_of_day..Time.zone.now.end_of_day)
                              .where(enabled: true)
                              .distinct
      @word_occurrences = combined_entries.word_occurrences
    else
      # OLD: Fallback to old method (N+1 queries)
      all_entry_ids = []
      @topicos.each do |topic|
        topic_entries = topic.list_entries
        all_entry_ids.concat(topic_entries.pluck(:id))
      end
      
      unique_entry_ids = all_entry_ids.uniq
      combined_entries = Entry.where(id: unique_entry_ids).joins(:site)
      @word_occurrences = combined_entries.word_occurrences
    end

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
      system('bundle install')

      # Migrate the database
      system('RAILS_ENV=production rails db:migrate')

      # Precompile assets
      system('RAILS_ENV=production rake assets:precompile')

      # Clear Rails cache to see changes immediately
      system('RAILS_ENV=production rails cache:clear')

      # Restart the Puma server
      system('touch tmp/restart.txt')
    end

    render plain: 'Deployment complete!'
  end

  def check
    @url = params[:url]
    @doc = Nokogiri::HTML(URI.parse(@url).open('User-Agent' => 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/92.0.4515.159 Safari/537.36'))
    @result = WebExtractorServices::ExtractDate.call(@doc)
    render layout: false
  end
end

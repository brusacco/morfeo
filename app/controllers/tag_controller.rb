# frozen_string_literal: true

class TagController < ApplicationController
  before_action :authenticate_user!

  def entries_data
    tag_id = params[:tag_id]
    date_filter = params[:date]
    polarity = params[:polarity]
    title = params[:title]

    date = Date.parse(date_filter) if date_filter.present?

    tag = Tag.find_by(id: tag_id)
    polarity = validate_polarity(polarity)

    if tag
      if title == 'true'
        entries = tag.title_list_entries
      else
        entries = tag.list_entries
      end

      entries = entries.where(published_at: date.all_day) if date

      entries = entries.where(polarity:) if polarity
    end

    case polarity
    when 'neutral', '0'
      polarityName = 'Neutral'
    when 'positive', '1'
      polarityName = 'Positiva'
    when 'negative', '2'
      polarityName = 'Negativa'
    else
      polarityName = 'Todas'
    end

    render partial: 'home/chart_entries',
           locals: {
             topic_entries: entries,
             entries_date: date,
             topic: tag.name,
             polarity: polarityName
           },
           layout: false
  end

  def validate_polarity(polarity)
    valid_polarities = %w[neutral positive negative 0 1 2]
    valid_polarities.include?(polarity) ? polarity : nil
  end

  def show
    @tag = Tag.find(params[:id])
    @entries = @tag.list_entries

    @total_entries = @entries.size
    @total_interactions = @entries.sum(:total_count)

    @comments = Comment.where(entry_id: @entries.select(:id))
    @comments_word_occurrences = @comments.word_occurrences

    @word_occurrences = @entries.word_occurrences
    @bigram_occurrences = @entries.bigram_occurrences

    polarity_counts = @entries.group(:polarity).count
    @neutrals = polarity_counts['neutral'] || 0
    @positives = polarity_counts['positive'] || 0
    @negatives = polarity_counts['negative'] || 0

    @percentage_positives = safe_percentage(@positives, @entries.size)
    @percentage_negatives = safe_percentage(@negatives, @entries.size)
    @percentage_neutrals = safe_percentage(@neutrals, @entries.size)

    @promedio = @total_entries.zero? ? 0 : @total_interactions / @total_entries

    @most_interactions = @entries.order(total_count: :desc).limit(20)

    @title_entries = @tag.title_list_entries
    @title_chart_entries = @title_entries.group_by_day(:published_at)
    @title_chart_entries_counts = @title_chart_entries.count
    @title_chart_entries_sums = @title_chart_entries.sum(:total_count)

    @site_top_counts = @entries.group('site_id').order(Arel.sql('COUNT(*) DESC')).limit(12).count
    @site_counts = @entries.group('sites.name').count('*')
    @site_sums = @entries.group('sites.name').sum(:total_count)

    @tags = @entries.tag_counts_on(:tags).where.not(id: @tag.id).order('count desc').limit(50)

    @tags_interactions = Entry.joins(:tags)
                              .where(id: @entries.select(:id), tags: { id: @tags.map(&:id) })
                              .group('tags.name')
                              .order(Arel.sql('SUM(total_count) DESC'))
                              .sum(:total_count)
    @tags_count = {}
    @tags.each { |n| @tags_count[n.name] = n.count }
    
    # Temporal Intelligence Data
    load_temporal_intelligence_data
  end

  def comments
    @tag = Tag.find(params[:id])
    @entries = Entry.enabled.normal_range.joins(:site).tagged_with(@tag.name).has_image.order(published_at: :desc)

    @comments = Comment.where(entry_id: @entries.select(:id)).order(created_time: :desc)
    @comments_word_occurrences = @comments.word_occurrences
    # @comments_bigram_occurrences = @comments.bigram_occurrences

    @tm = TextMood.new(language: 'es', normalize_score: true)
  end

  def report
    @tag = Tag.find(params[:id])
    @entries = Entry.enabled.normal_range.joins(:site).tagged_with(@tag.name).has_image.order(published_at: :desc)
    @tags = @entries.tag_counts_on(:tags).order('count desc').limit(20)

    @tags_interactions = Entry.joins(:tags)
                              .where(id: @entries.select(:id), tags: { id: @tags.map(&:id) })
                              .group('tags.name')
                              .order(Arel.sql('SUM(total_count) DESC'))
                              .sum(:total_count)

    @tags_count = {}
    @tags.each { |n| @tags_count[n.name] = n.count }

    render layout: false
  end

  def search
    query = params[:query].strip
    @tags = Tag.where('name LIKE?', "%#{query}%")
  end

  private

  def safe_percentage(numerator, denominator)
    denominator.positive? ? (Float(numerator) / denominator * 100).round(0) : 0
  end
  
  def load_temporal_intelligence_data
    begin
      @temporal_summary = calculate_temporal_summary
    rescue StandardError => e
      Rails.logger.error "❌ Error loading temporal_summary: #{e.class} - #{e.message}"
      @temporal_summary = nil
    end
    
    begin
      @optimal_time = calculate_optimal_publishing_time
    rescue StandardError => e
      Rails.logger.error "❌ Error loading optimal_time: #{e.message}"
      @optimal_time = nil
    end
    
    begin
      @trend_velocity = calculate_trend_velocity
    rescue StandardError => e
      Rails.logger.error "❌ Error loading trend_velocity: #{e.message}"
      @trend_velocity = { velocity_percent: 0, direction: 'stable' }
    end
    
    begin
      @engagement_velocity = calculate_engagement_velocity
    rescue StandardError => e
      Rails.logger.error "❌ Error loading engagement_velocity: #{e.message}"
      @engagement_velocity = { velocity_percent: 0, direction: 'stable' }
    end
    
    begin
      @content_half_life = calculate_content_half_life
    rescue StandardError => e
      Rails.logger.error "❌ Error loading content_half_life: #{e.message}"
      @content_half_life = nil
    end
    
    begin
      @peak_hours = calculate_peak_hours
    rescue StandardError => e
      Rails.logger.error "❌ Error loading peak_hours: #{e.message}"
      @peak_hours = {}
    end
    
    begin
      @peak_days = calculate_peak_days
    rescue StandardError => e
      Rails.logger.error "❌ Error loading peak_days: #{e.message}"
      @peak_days = {}
    end
    
    begin
      @heatmap_data = calculate_heatmap_data
    rescue StandardError => e
      Rails.logger.error "❌ Error loading heatmap_data: #{e.message}"
      @heatmap_data = []
    end
  end
  
  def calculate_temporal_summary
    return nil if @entries.empty?
    
    {
      total_entries: @total_entries,
      total_interactions: @total_interactions,
      avg_interactions: @promedio
    }
  end
  
  def calculate_optimal_publishing_time
    return nil if @entries.empty?
    
    # Group by day of week and hour
    by_time = @entries.group_by { |e| [e.published_at.strftime('%A'), e.published_at.hour] }
    
    return nil if by_time.empty?
    
    # Calculate average engagement for each time slot
    time_stats = by_time.map do |(day, hour), entries|
      {
        day: day,
        hour: hour,
        avg_engagement: entries.sum(&:total_count).to_f / entries.size,
        entry_count: entries.size
      }
    end
    
    # Find the best time (minimum 3 entries required)
    best = time_stats.select { |s| s[:entry_count] >= 3 }.max_by { |s| s[:avg_engagement] }
    
    best || time_stats.max_by { |s| s[:avg_engagement] }
  end
  
  def calculate_trend_velocity
    recent_entries = @entries.where('published_at >= ?', 24.hours.ago)
    previous_entries = @entries.where('published_at >= ? AND published_at < ?', 48.hours.ago, 24.hours.ago)
    
    recent_count = recent_entries.count
    previous_count = previous_entries.count
    
    return { velocity_percent: 0, direction: 'stable', trend: 'estable', recent_count: recent_count } if previous_count.zero?
    
    velocity_percent = ((recent_count - previous_count).to_f / previous_count * 100).round(1)
    
    direction = if velocity_percent > 10
                  'up'
                elsif velocity_percent < -10
                  'down'
                else
                  'stable'
                end
    
    trend = case direction
            when 'up' then 'al alza'
            when 'down' then 'a la baja'
            else 'estable'
            end
    
    {
      velocity_percent: velocity_percent,
      direction: direction,
      trend: trend,
      recent_count: recent_count,
      previous_count: previous_count
    }
  end
  
  def calculate_engagement_velocity
    recent_entries = @entries.where('published_at >= ?', 24.hours.ago)
    previous_entries = @entries.where('published_at >= ? AND published_at < ?', 48.hours.ago, 24.hours.ago)
    
    recent_interactions = recent_entries.sum(:total_count)
    previous_interactions = previous_entries.sum(:total_count)
    
    return { velocity_percent: 0, direction: 'stable', trend: 'estable', recent_interactions: recent_interactions } if previous_interactions.zero?
    
    velocity_percent = ((recent_interactions - previous_interactions).to_f / previous_interactions * 100).round(1)
    
    direction = if velocity_percent > 10
                  'up'
                elsif velocity_percent < -10
                  'down'
                else
                  'stable'
                end
    
    trend = case direction
            when 'up' then 'creciendo'
            when 'down' then 'decreciendo'
            else 'estable'
            end
    
    {
      velocity_percent: velocity_percent,
      direction: direction,
      trend: trend,
      recent_interactions: recent_interactions,
      previous_interactions: previous_interactions
    }
  end
  
  def calculate_content_half_life
    return nil if @entries.empty?
    
    # Calculate time differences between entries
    sorted_entries = @entries.order(:published_at)
    return nil if sorted_entries.count < 2
    
    # Calculate median hours between entries
    time_diffs = []
    sorted_entries.each_cons(2) do |a, b|
      hours_diff = ((b.published_at - a.published_at) / 1.hour).round
      time_diffs << hours_diff if hours_diff > 0
    end
    
    return nil if time_diffs.empty?
    
    median_hours = time_diffs.sort[time_diffs.length / 2]
    
    {
      median_hours: median_hours,
      sample_size: sorted_entries.count
    }
  end
  
  def calculate_peak_hours
    return {} if @entries.empty?
    
    by_hour = @entries.group_by { |e| e.published_at.hour }
    
    by_hour.transform_values do |entries|
      {
        entry_count: entries.size,
        total_engagement: entries.sum(&:total_count),
        avg_engagement: entries.sum(&:total_count).to_f / entries.size
      }
    end
  end
  
  def calculate_peak_days
    return {} if @entries.empty?
    
    day_names = ['Domingo', 'Lunes', 'Martes', 'Miércoles', 'Jueves', 'Viernes', 'Sábado']
    
    by_day = @entries.group_by { |e| day_names[e.published_at.wday] }
    
    by_day.transform_values do |entries|
      {
        entry_count: entries.size,
        total_engagement: entries.sum(&:total_count),
        avg_engagement: entries.sum(&:total_count).to_f / entries.size
      }
    end.sort_by { |day, _| day_names.index(day) }.to_h
  end
  
  def calculate_heatmap_data
    return [] if @entries.empty?
    
    # Group by day of week (0-6) and hour (0-23)
    heatmap = @entries.group_by { |e| [e.published_at.wday, e.published_at.hour] }
    
    heatmap.map do |(day, hour), entries|
      {
        day_number: day,
        hour: hour,
        entry_count: entries.size,
        total_engagement: entries.sum(&:total_count),
        avg_engagement: (entries.sum(&:total_count).to_f / entries.size).round(1)
      }
    end
  end
end

# frozen_string_literal: true

class TopicController < ApplicationController
  before_action :authenticate_user!

  # caches_action :show, expires_in: 1.hour

  def entries_data
    topic_id = params[:topic_id]
    date_filter = params[:date]
    polarity = params[:polarity]
    title = params[:title]

    date = Date.parse(date_filter) if date_filter.present?

    topic = Topic.find_by(id: topic_id)
    polarity = validate_polarity(polarity)

    if topic
      if title == 'true'
        entries = topic.title_chart_entries(date)
      else
        entries = topic.chart_entries(date)
      end

      entries = entries.where(published_at: date.all_day)

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
             topic: topic.name,
             polarity: polarityName
           },
           layout: false
  end

  def validate_polarity(polarity)
    valid_polarities = %w[neutral positive negative 0 1 2]
    valid_polarities.include?(polarity) ? polarity : nil
  end

  def show
    @topic = Topic.find(params[:id])

    unless @topic.users.exists?(current_user.id) && @topic.status == true
      return redirect_to root_path,
                         alert: 'El Tópico al que intentaste acceder no está asignado a tu usuario o se encuentra deshabilitado'
    end

    load_topic_data
    load_chart_data
    calculate_percentages
    load_tags_and_word_data
    load_temporal_intelligence
  end

  def comments
    @topic = Topic.find(params[:id])

    unless @topic.users.exists?(current_user.id)
      return redirect_to root_path, alert: 'El Tópico al que intentaste acceder no está asignado a tu usuario'
    end

    @tag_list = @topic.tags.map(&:name)
    @entries = @topic.list_entries

    @positive_words = @topic.positive_words.split(',') if @topic.positive_words.present?
    @negative_words = @topic.negative_words.split(',') if @topic.negative_words.present?

    @comments = Comment.where(entry_id: @entries.select(:id)).order(created_time: :desc)
    @comments_word_occurrences = @comments.word_occurrences
    # @comments_bigram_occurrences = @comments.bigram_occurrences

    @tm = TextMood.new(language: 'es', normalize_score: true)
  end

  def pdf
    @topic = Topic.includes(:tags, :users).find(params[:id])

    unless @topic.users.exists?(current_user.id) && @topic.status == true
      return redirect_to root_path,
                         alert: 'El Tópico al que intentaste acceder no está asignado a tu usuario o se encuentra deshabilitado'
    end

    load_topic_data
    load_chart_data
    calculate_percentages_for_pdf
    load_tags_and_word_data

    # Render with specific layout for PDF
    render layout: false
  end

  def history
    @topic = Topic.find(params[:id])
    @reports = @topic.reports.where.not(report_text: nil).order(created_at: :desc).limit(20)
  end

  private

  def load_topic_data
    @tag_list = @topic.tags.map(&:name)
    @entries = @topic.list_entries

    # Precompute aggregates to avoid multiple SQL queries
    @entries_count = @entries.size
    @entries_total_sum = @entries.sum(:total_count)

    # Combine polarity aggregations into a single query
    @entries_polarity_data = @entries
                             .where.not(polarity: nil)
                             .group(:polarity)
                             .pluck(
                               :polarity,
                               Arel.sql('COUNT(*)'),
                               Arel.sql('SUM(entries.total_count)')
                             )
                             .map { |p, c, s| [p, { count: c, sum: s }] }
                             .to_h

    # Extract counts and sums from the combined data
    @entries_polarity_counts = @entries_polarity_data.transform_values { |v| v[:count] }
    @entries_polarity_sums = @entries_polarity_data.transform_values { |v| v[:sum] }

    # Precompute site group queries to avoid duplicate group-by operations
    @site_counts =
      Rails.cache.fetch("topic_#{@topic.id}_site_counts", expires_in: 1.hour) do
        @entries.group('sites.name').count('*')
      end
    @site_sums =
      Rails.cache.fetch("topic_#{@topic.id}_site_sums", expires_in: 1.hour) do
        @entries.group('sites.name').sum(:total_count)
      end

    @total_entries = @entries_count
    @total_interactions = @entries_total_sum
  end

  def load_chart_data
    # Use pre-aggregated daily stats for performance
    topic_stats = @topic.topic_stat_dailies.normal_range.order(:topic_date)
    
    # Build chart data from aggregated stats
    @chart_entries_counts = topic_stats.pluck(:topic_date, :entry_count).to_h
    @chart_entries_sums = topic_stats.pluck(:topic_date, :total_count).to_h
    
    # Sentiment chart data from aggregated stats
    @chart_entries_sentiments_counts = {}
    @chart_entries_sentiments_sums = {}
    
    topic_stats.each do |stat|
      date = stat.topic_date
      # Counts by sentiment
      @chart_entries_sentiments_counts[['positive', date]] = stat.positive_quantity || 0
      @chart_entries_sentiments_counts[['neutral', date]] = stat.neutral_quantity || 0
      @chart_entries_sentiments_counts[['negative', date]] = stat.negative_quantity || 0
      
      # Interactions by sentiment
      @chart_entries_sentiments_sums[['positive', date]] = stat.positive_interaction || 0
      @chart_entries_sentiments_sums[['neutral', date]] = stat.neutral_interaction || 0
      @chart_entries_sentiments_sums[['negative', date]] = stat.negative_interaction || 0
    end
    
    # Use pre-aggregated title stats for performance
    title_stats = @topic.title_topic_stat_dailies.normal_range.order(:topic_date)
    
    @title_chart_entries_counts = title_stats.pluck(:topic_date, :entry_quantity).to_h
    @title_chart_entries_sums = title_stats.pluck(:topic_date, :entry_interaction).to_h
  end

  def calculate_percentages
    # Calculate all entries stats (for show action)
    all_entries = @topic.all_list_entries
    @all_entries_size = all_entries.size
    @all_entries_interactions = all_entries.sum(:total_count)

    calculate_sentiment_and_comparison_percentages
  end

  def calculate_percentages_for_pdf
    # Calculate all entries stats differently for PDF (excludes current topic entries)
    @all_entries_size = Entry.enabled.normal_range.where.not(id: @entries.ids).count
    @all_entries_interactions = Entry.enabled.normal_range.where.not(id: @entries.ids).sum(:total_count)

    calculate_sentiment_and_comparison_percentages
  end

  def calculate_sentiment_and_comparison_percentages
    @neutrals = @entries_polarity_counts['neutral'] || 0
    @positives = @entries_polarity_counts['positive'] || 0
    @negatives = @entries_polarity_counts['negative'] || 0

    if @entries_count > 0
      @percentage_positives = (Float(@positives) / @entries_count * 100).round(0)
      @percentage_negatives = (Float(@negatives) / @entries_count * 100).round(0)
      @percentage_neutrals = (Float(@neutrals) / @entries_count * 100).round(0)

      total_count = @entries_count + @all_entries_size
      if total_count > 0
        @topic_percentage = (Float(@entries_count) / total_count * 100).round(0)
        @all_percentage = (Float(@all_entries_size) / total_count * 100).round(0)
      end

      total_interactions = @entries_total_sum + @all_entries_interactions
      if total_interactions > 0
        @topic_interactions_percentage = (Float(@entries_total_sum) / total_interactions * 100).round(1)
        @all_intereactions_percentage = (Float(@all_entries_interactions) / total_interactions * 100).round(1)
      end
    end

    @promedio = @total_entries.zero? ? 0 : @total_interactions / @total_entries
    @most_interactions = @entries.order(total_count: :desc).limit(20)
  end

  def load_tags_and_word_data
    # Word occurrences and bigrams
    @word_occurrences =
      Rails.cache.fetch("topic_#{@topic.id}_word_occurrences", expires_in: 1.hour) do
        @entries.word_occurrences
      end
    @bigram_occurrences =
      Rails.cache.fetch("topic_#{@topic.id}_bigram_occurrences", expires_in: 1.hour) do
        @entries.bigram_occurrences
      end
    
    @report = @topic.reports.last

    # Comments data (empty for now, comments feature disabled)
    @comments = []
    @comments_word_occurrences = []

    # Sentiment words
    @positive_words = @topic.positive_words.split(',') if @topic.positive_words.present?
    @negative_words = @topic.negative_words.split(',') if @topic.negative_words.present?

    # Tags analysis
    @tags = Tag.joins(:taggings)
               .where(taggings: {
                        taggable_type: Entry.base_class.name,
                        context: 'tags',
                        taggable_id: @entries.select(:id)
                      })
               .group('tags.id', 'tags.name')
               .order(Arel.sql('COUNT(DISTINCT taggings.taggable_id) DESC'))
               .limit(20)
               .select('tags.id, tags.name, COUNT(DISTINCT taggings.taggable_id) AS count')

    @tags_interactions = Entry.joins(:tags)
                              .where(id: @entries.select(:id), tags: { id: @tags.map(&:id) })
                              .group('tags.name')
                              .sum(:total_count)

    @tags_count = {}
    @tags.each { |n| @tags_count[n.name] = n.count }

    # Top sites
    @site_top_counts = @entries.group('site_id').order(Arel.sql('COUNT(*) DESC')).limit(12).count
  end

  def load_temporal_intelligence
    # Load temporal intelligence data
    begin
      @temporal_summary = @topic.temporal_intelligence_summary
      Rails.logger.info "✅ temporal_summary loaded successfully"
    rescue StandardError => e
      Rails.logger.error "❌ Error loading temporal_summary: #{e.class} - #{e.message}"
      Rails.logger.error e.backtrace.first(5).join("\n")
      @temporal_summary = nil
    end
    
    begin
      @optimal_time = @topic.optimal_publishing_time
      Rails.logger.info "✅ optimal_time loaded successfully: #{@optimal_time.inspect}"
    rescue StandardError => e
      Rails.logger.error "❌ Error loading optimal_time: #{e.class} - #{e.message}"
      Rails.logger.error e.backtrace.first(5).join("\n")
      @optimal_time = nil
    end
    
    begin
      @trend_velocity = @topic.trend_velocity
    rescue StandardError => e
      Rails.logger.error "❌ Error loading trend_velocity: #{e.message}"
      @trend_velocity = { velocity_percent: 0, direction: 'stable' }
    end
    
    begin
      @engagement_velocity = @topic.engagement_velocity
    rescue StandardError => e
      Rails.logger.error "❌ Error loading engagement_velocity: #{e.message}"
      @engagement_velocity = { velocity_percent: 0, direction: 'stable' }
    end
    
    begin
      @content_half_life = @topic.content_half_life
    rescue StandardError => e
      Rails.logger.error "❌ Error loading content_half_life: #{e.message}"
      @content_half_life = nil
    end
    
    begin
      @peak_hours = @topic.peak_publishing_times_by_hour
    rescue StandardError => e
      Rails.logger.error "❌ Error loading peak_hours: #{e.message}"
      @peak_hours = {}
    end
    
    begin
      @peak_days = @topic.peak_publishing_times_by_day
    rescue StandardError => e
      Rails.logger.error "❌ Error loading peak_days: #{e.message}"
      @peak_days = {}
    end
    
    begin
      @heatmap_data = @topic.engagement_heatmap_data
    rescue StandardError => e
      Rails.logger.error "❌ Error loading heatmap_data: #{e.message}"
      @heatmap_data = []
    end
  end
end

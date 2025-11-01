# frozen_string_literal: true

module HomeServices
  # Service for aggregating home dashboard data across all topics
  # Handles multi-channel analytics, executive summaries, and competitive intelligence
  #
  # @example
  #   data = HomeServices::DashboardAggregatorService.call(topics: @user.topics, days_range: 30)
  #   data[:executive_summary][:total_mentions]  # => Total mentions across all channels
  #   data[:sentiment_intelligence]              # => Sentiment analysis data
  class DashboardAggregatorService < ApplicationService
    # Constants
    CACHE_EXPIRATION = 30.minutes
    DIGITAL_REACH_MULTIPLIER = 3  # Conservative estimate for digital media
    TWITTER_REACH_FALLBACK = 10   # Fallback multiplier when views_count unavailable
    
    # Alert thresholds
    CRISIS_SENTIMENT_THRESHOLD = -40
    WARNING_SENTIMENT_THRESHOLD = -20
    ALERT_MINIMUM_COUNT = 10
    
    # Competitive intelligence thresholds
    COMPETITIVE_SOV_THRESHOLD = 15
    STRONG_SOV_THRESHOLD = 20
    DOMINANT_SOV_THRESHOLD = 30
    GROWTH_THRESHOLD = 20

    def initialize(topics:, days_range: DAYS_RANGE)
      @topics = topics
      @days_range = days_range
      @start_date = days_range.days.ago.beginning_of_day
      @end_date = Time.current
      @tag_names_cache = nil # Memoization for tag names
      @channel_stats_cache = {} # Memoization for channel stats
    end

    def call
      Rails.cache.fetch(cache_key, expires_in: CACHE_EXPIRATION) do
        {
          executive_summary: calculate_executive_summary,
          channel_stats: calculate_channel_stats,
          topic_stats: calculate_topic_stats,
          topic_trends: calculate_topic_trends,
          alerts: generate_alerts,
          top_content: fetch_top_content,
          # Phase 2: Enhanced Analytics
          sentiment_intelligence: calculate_sentiment_intelligence,
          temporal_intelligence: calculate_temporal_intelligence,
          competitive_intelligence: calculate_competitive_intelligence
        }
      end
    end

    private

    def cache_key
      "home_dashboard_#{@topics.map(&:id).sort.join('_')}_#{@days_range}_#{Date.current}"
    end

    # Memoized tag names to avoid multiple pluck calls
    def tag_names
      @tag_names_cache ||= @topics.flat_map { |t| t.tags.pluck(:name) }.uniq
    end

    # Memoized channel stats to avoid recalculation
    def channel_stats(channel)
      @channel_stats_cache[channel] ||= send("#{channel}_channel_stats")
    end

    # ========================================
    # EXECUTIVE SUMMARY
    # ========================================

    def calculate_executive_summary
      digital = channel_stats(:digital)
      facebook = channel_stats(:facebook)
      twitter = channel_stats(:twitter)

      total_mentions = digital[:mentions] + facebook[:mentions] + twitter[:mentions]
      total_interactions = digital[:interactions] + facebook[:interactions] + twitter[:interactions]
      total_reach = digital[:reach] + facebook[:reach] + twitter[:reach]

      previous_interactions = calculate_previous_period_interactions

      {
        total_mentions: total_mentions,
        total_interactions: total_interactions,
        total_reach: total_reach,
        average_sentiment: calculate_weighted_sentiment(digital, facebook, twitter, total_mentions),
        engagement_rate: safe_percentage(total_interactions, total_reach, decimals: 2),
        trend_velocity: calculate_trend_velocity(total_interactions, previous_interactions),
        period: {
          days: @days_range,
          start: @start_date,
          end: @end_date
        }
      }
    end

    # ========================================
    # CHANNEL STATISTICS
    # ========================================

    def calculate_channel_stats
      digital = channel_stats(:digital)
      facebook = channel_stats(:facebook)
      twitter = channel_stats(:twitter)

      total_mentions = digital[:mentions] + facebook[:mentions] + twitter[:mentions]

      {
        digital: enrich_channel_stats(digital, total_mentions, 'Medios Digitales', 'indigo', 'fa-solid fa-newspaper'),
        facebook: enrich_channel_stats(facebook, total_mentions, 'Facebook', 'blue', 'fa-brands fa-facebook'),
        twitter: enrich_channel_stats(twitter, total_mentions, 'Twitter', 'sky', 'fa-brands fa-twitter')
      }
    end

    def enrich_channel_stats(stats, total_mentions, name, color, icon)
      stats.merge(
        share: safe_percentage(stats[:mentions], total_mentions, decimals: 1),
        color: color,
        name: name,
        icon: icon
      )
    end

    def digital_channel_stats
      return zero_stats if tag_names.empty?

      base_scope = -> { Entry.enabled.where(published_at: @start_date..@end_date).tagged_with(tag_names, any: true) }

      mentions = base_scope.call.distinct.count(:id)
      interactions = base_scope.call.sum(:total_count)
      reach = interactions * DIGITAL_REACH_MULTIPLIER
      prev_interactions = Entry.enabled
                               .where(published_at: (@start_date - @days_range.days)..@start_date)
                               .tagged_with(tag_names, any: true)
                               .sum(:total_count)

      {
        mentions: mentions,
        interactions: interactions,
        reach: reach,
        engagement_rate: safe_percentage(interactions, reach, decimals: 2),
        trend: calculate_trend_percent(interactions, prev_interactions),
        sentiment: calculate_digital_sentiment
      }
    end

    def facebook_channel_stats
      return zero_stats if tag_names.empty?

      base_scope = -> { FacebookEntry.where(posted_at: @start_date..@end_date).tagged_with(tag_names, any: true) }
      interaction_sql = Arel.sql('reactions_total_count + comments_count + share_count')

      mentions = base_scope.call.distinct.count(:id)
      interactions = base_scope.call.sum(interaction_sql)
      reach = base_scope.call.sum(:views_count) # Actual API data
      prev_interactions = FacebookEntry.where(posted_at: (@start_date - @days_range.days)..@start_date)
                                      .tagged_with(tag_names, any: true)
                                      .sum(interaction_sql)

      {
        mentions: mentions,
        interactions: interactions,
        reach: reach,
        engagement_rate: safe_percentage(interactions, reach, decimals: 2),
        trend: calculate_trend_percent(interactions, prev_interactions),
        sentiment: calculate_facebook_sentiment
      }
    end

    def twitter_channel_stats
      return zero_stats if tag_names.empty?

      base_scope = -> { TwitterPost.where(posted_at: @start_date..@end_date).tagged_with(tag_names, any: true) }
      interaction_sql = Arel.sql('favorite_count + retweet_count + reply_count + quote_count')

      mentions = base_scope.call.distinct.count(:id)
      interactions = base_scope.call.sum(interaction_sql)
      views = base_scope.call.sum(:views_count)
      reach = views > 0 ? views : interactions * TWITTER_REACH_FALLBACK
      prev_interactions = TwitterPost.where(posted_at: (@start_date - @days_range.days)..@start_date)
                                     .tagged_with(tag_names, any: true)
                                     .sum(interaction_sql)

      {
        mentions: mentions,
        interactions: interactions,
        reach: reach,
        engagement_rate: safe_percentage(interactions, reach, decimals: 2),
        trend: calculate_trend_percent(interactions, prev_interactions),
        sentiment: 0.0 # Twitter sentiment not implemented yet
      }
    end

    def zero_stats
      {
        mentions: 0,
        interactions: 0,
        reach: 0,
        engagement_rate: 0,
        trend: 0,
        sentiment: 0
      }
    end

    # ========================================
    # TOPIC STATISTICS
    # ========================================

    def calculate_topic_stats
      # Batch load all stats for performance
      stats_by_topic = load_topic_stats_batch

      @topics.each_with_object({}) do |topic, hash|
        stats = stats_by_topic[topic.id] || []
        
        hash[topic.id] = {
          mentions: stats.sum { |s| s.entry_count || 0 },
          interactions: stats.sum { |s| s.total_count || 0 },
          sentiment: calculate_topic_sentiment_from_stats(stats),
          trend_direction: calculate_topic_trend_direction_from_stats(stats)
        }
      end
    end

    def calculate_topic_trends
      # Batch load all stats for performance
      stats_by_topic = load_topic_stats_batch

      @topics.each_with_object({}) do |topic, hash|
        stats = stats_by_topic[topic.id] || []
        daily_data = stats.each_with_object({}) { |s, h| h[s.topic_date] = s.entry_count || 0 }

        hash[topic.id] = {
          data: daily_data,
          direction: calculate_topic_trend_direction_from_stats(stats)
        }
      end
    end

    def load_topic_stats_batch
      # Single query to load all stats for all topics
      TopicStatDaily.where(
        topic_id: @topics.map(&:id),
        topic_date: @start_date.to_date..@end_date.to_date
      ).group_by(&:topic_id)
    end

    def calculate_topic_sentiment_from_stats(stats)
      positive = stats.sum { |s| s.positive_quantity || 0 }
      negative = stats.sum { |s| s.negative_quantity || 0 }
      neutral = stats.sum { |s| s.neutral_quantity || 0 }
      total = positive + negative + neutral

      return 0 if total.zero?
      ((positive - negative).to_f / total * 100).round(1)
    end

    def calculate_topic_trend_direction_from_stats(stats)
      recent_stats = stats.select { |s| s.topic_date >= 3.days.ago.to_date }
      previous_stats = stats.select { |s| s.topic_date.between?(6.days.ago.to_date, 3.days.ago.to_date) }

      recent_count = recent_stats.sum { |s| s.entry_count || 0 }
      previous_count = previous_stats.sum { |s| s.entry_count || 0 }

      return 'stable' if recent_count == previous_count || previous_count.zero?
      recent_count > previous_count ? 'up' : 'down'
    end

    # ========================================
    # ALERTS
    # ========================================

    def generate_alerts
      alerts = []
      stats_by_topic = load_topic_stats_batch

      @topics.each do |topic|
        stats = stats_by_topic[topic.id] || []
        sentiment = calculate_topic_sentiment_from_stats(stats)
        trend = calculate_topic_trend_direction_from_stats(stats)

        # Sentiment alerts
        alerts.concat(generate_sentiment_alerts(topic, sentiment))
        
        # Trend alerts
        alerts << generate_trend_alert(topic, stats, trend) if trend == 'down'
      end

      alerts.compact.sort_by { |a| ['high', 'medium', 'low'].index(a[:severity]) }
    end

    def generate_sentiment_alerts(topic, sentiment)
      alerts = []

      if sentiment < CRISIS_SENTIMENT_THRESHOLD
        alerts << create_alert(
          severity: 'high',
          type: 'crisis',
          topic: topic,
          message: "⚠️ Crisis de Reputación: #{topic.name}",
          details: "Sentimiento muy negativo detectado (#{sentiment.round(1)}%). Requiere atención inmediata."
        )
      elsif sentiment < WARNING_SENTIMENT_THRESHOLD
        alerts << create_alert(
          severity: 'medium',
          type: 'warning',
          topic: topic,
          message: "⚡ Alerta de Sentimiento: #{topic.name}",
          details: "Tendencia negativa en menciones (#{sentiment.round(1)}%). Monitorear de cerca."
        )
      end

      alerts
    end

    def generate_trend_alert(topic, stats, trend)
      recent_count = stats.select { |s| s.topic_date >= 3.days.ago.to_date }.sum { |s| s.entry_count || 0 }
      
      return nil unless recent_count > ALERT_MINIMUM_COUNT

      create_alert(
        severity: 'low',
        type: 'info',
        topic: topic,
        message: "📉 Disminución de Menciones: #{topic.name}",
        details: "Las menciones están disminuyendo en los últimos días. Considere aumentar actividad."
      )
    end

    def create_alert(severity:, type:, topic:, message:, details:)
      {
        severity: severity,
        type: type,
        message: message,
        details: details,
        topic: topic.name,
        url: Rails.application.routes.url_helpers.topic_path(topic)
      }
    end

    # ========================================
    # TOP CONTENT
    # ========================================

    def fetch_top_content
      return empty_top_content if tag_names.empty?

      {
        top_entries: fetch_top_digital_entries,
        top_facebook_posts: fetch_top_facebook_posts,
        top_tweets: fetch_top_tweets
      }
    end

    def fetch_top_digital_entries
      Entry.enabled
           .where(published_at: @start_date..@end_date)
           .tagged_with(tag_names, any: true)
           .includes(:site)
           .order(Arel.sql('total_count DESC'))
           .limit(5)
    end

    def fetch_top_facebook_posts
      FacebookEntry.where(posted_at: @start_date..@end_date)
                   .tagged_with(tag_names, any: true)
                   .includes(:page)
                   .order(Arel.sql('reactions_total_count + comments_count + share_count DESC'))
                   .limit(5)
    end

    def fetch_top_tweets
      TwitterPost.where(posted_at: @start_date..@end_date)
                 .tagged_with(tag_names, any: true)
                 .includes(:twitter_profile)
                 .order(Arel.sql('favorite_count + retweet_count + reply_count + quote_count DESC'))
                 .limit(5)
    end

    def empty_top_content
      {
        top_entries: Entry.none,
        top_facebook_posts: FacebookEntry.none,
        top_tweets: TwitterPost.none
      }
    end

    # ========================================
    # SENTIMENT CALCULATIONS
    # ========================================

    def calculate_weighted_sentiment(digital, facebook, twitter, total_mentions)
      return 0 if total_mentions.zero?

      weighted_sum = (digital[:sentiment] * digital[:mentions]) +
                     (facebook[:sentiment] * facebook[:mentions]) +
                     (twitter[:sentiment] * twitter[:mentions])

      (weighted_sum / total_mentions).round(1)
    end

    def calculate_digital_sentiment
      return 0 if tag_names.empty?

      # Use .size instead of .count after tagged_with for efficiency
      base_scope = Entry.enabled.where(published_at: @start_date..@end_date).tagged_with(tag_names, any: true)
      
      positive = base_scope.where(polarity: :positive).size
      negative = base_scope.where(polarity: :negative).size
      total = base_scope.size

      return 0 if total.zero?
      ((positive - negative).to_f / total * 100).round(1)
    end

    def calculate_facebook_sentiment
      return 0 if tag_names.empty?

      base_scope = FacebookEntry.where(posted_at: @start_date..@end_date).tagged_with(tag_names, any: true)
      
      total_score = base_scope.sum(:sentiment_score)
      count = base_scope.where.not(sentiment_score: nil).size

      return 0 if count.zero?
      # Convert FacebookEntry sentiment_score (-2.0 to +2.0) to percentage (-100 to +100)
      (total_score / count * 50).round(1)
    end

    def calculate_previous_period_interactions
      return 0 if tag_names.empty?

      digital = Entry.enabled
                     .where(published_at: (@start_date - @days_range.days)..@start_date)
                     .tagged_with(tag_names, any: true)
                     .sum(:total_count)

      facebook = FacebookEntry.where(posted_at: (@start_date - @days_range.days)..@start_date)
                              .tagged_with(tag_names, any: true)
                              .sum(Arel.sql('reactions_total_count + comments_count + share_count'))

      twitter = TwitterPost.where(posted_at: (@start_date - @days_range.days)..@start_date)
                           .tagged_with(tag_names, any: true)
                           .sum(Arel.sql('favorite_count + retweet_count + reply_count + quote_count'))

      digital + facebook + twitter
    end

    # ========================================
    # PHASE 2: SENTIMENT INTELLIGENCE
    # ========================================

    def calculate_sentiment_intelligence
      {
        evolution: sentiment_evolution_over_time,
        by_topic: sentiment_by_topic,
        by_channel: sentiment_by_channel,
        controversial_content: find_controversial_content,
        confidence_metrics: calculate_sentiment_confidence
      }
    end

    def sentiment_evolution_over_time
      # Batch load all stats for performance
      all_stats = TopicStatDaily.where(
        topic_id: @topics.map(&:id),
        topic_date: @start_date.to_date..@end_date.to_date
      ).group_by(&:topic_date)

      (@start_date.to_date..@end_date.to_date).each_with_object({}) do |date, hash|
        stats = all_stats[date] || []
        
        positive = stats.sum { |s| s.positive_quantity || 0 }
        negative = stats.sum { |s| s.negative_quantity || 0 }
        neutral = stats.sum { |s| s.neutral_quantity || 0 }
        total = positive + negative + neutral
        
        score = total > 0 ? ((positive - negative).to_f / total * 100).round(1) : 0
        hash[date.strftime('%Y-%m-%d')] = score
      end
    end

    def sentiment_by_topic
      stats_by_topic = load_topic_stats_batch

      @topics.each_with_object({}) do |topic, hash|
        stats = stats_by_topic[topic.id] || []
        hash[topic.name] = calculate_topic_sentiment_from_stats(stats)
      end
    end

    def sentiment_by_channel
      {
        digital: channel_stats(:digital)[:sentiment],
        facebook: channel_stats(:facebook)[:sentiment],
        twitter: channel_stats(:twitter)[:sentiment]
      }
    end

    def find_controversial_content
      return [] if tag_names.empty?

      FacebookEntry.where(posted_at: @start_date..@end_date)
                   .tagged_with(tag_names, any: true)
                   .where('controversy_index > ?', 0.6)
                   .order(controversy_index: :desc)
                   .limit(5)
                   .includes(:page)
                   .map { |post| format_controversial_post(post) }
    end

    def format_controversial_post(post)
      {
        type: 'facebook',
        title: post.message&.truncate(80) || 'Ver publicación',
        url: post.permalink_url,
        source: post.page.name,
        controversy_index: post.controversy_index.round(2),
        reactions: post.reactions_total_count
      }
    end

    def calculate_sentiment_confidence
      return { confidence: 0, sample_size: 0, reliability: 'very_low' } if tag_names.empty?

      digital_count = Entry.enabled
                           .where(published_at: @start_date..@end_date)
                           .tagged_with(tag_names, any: true)
                           .size

      facebook_count = FacebookEntry.where(posted_at: @start_date..@end_date)
                                    .tagged_with(tag_names, any: true)
                                    .where.not(sentiment_score: nil)
                                    .size

      total_sample = digital_count + facebook_count

      confidence = calculate_confidence_level(total_sample)
      reliability = calculate_reliability_label(confidence)

      {
        confidence: confidence,
        sample_size: total_sample,
        reliability: reliability
      }
    end

    def calculate_confidence_level(sample_size)
      case sample_size
      when 0...10 then 0.20
      when 10...50 then 0.50
      when 50...200 then 0.70
      when 200...1000 then 0.85
      else 0.95
      end
    end

    def calculate_reliability_label(confidence)
      case confidence
      when 0...0.3 then 'very_low'
      when 0.3...0.5 then 'low'
      when 0.5...0.7 then 'moderate'
      when 0.7...0.9 then 'good'
      else 'high'
      end
    end

    # ========================================
    # PHASE 2: TEMPORAL INTELLIGENCE
    # ========================================

    def calculate_temporal_intelligence
      {
        peak_hours: calculate_peak_hours,
        peak_days: calculate_peak_days,
        best_publishing_times: recommend_publishing_times
      }
    end

    def calculate_peak_hours
      return {} if tag_names.empty?

      hourly_data = Hash.new(0)

      # Batch load posts with interactions
      load_facebook_hourly_data(hourly_data)
      load_twitter_hourly_data(hourly_data)

      # Ensure all 24 hours are present
      (0..23).each { |h| hourly_data[h] ||= 0 }

      hourly_data.sort.to_h
    end

    def load_facebook_hourly_data(hourly_data)
      FacebookEntry.where(posted_at: @start_date..@end_date)
                   .tagged_with(tag_names, any: true)
                   .pluck(:posted_at, Arel.sql('reactions_total_count + comments_count + share_count'))
                   .each { |posted_at, interactions| hourly_data[posted_at.hour] += interactions }
    end

    def load_twitter_hourly_data(hourly_data)
      TwitterPost.where(posted_at: @start_date..@end_date)
                 .tagged_with(tag_names, any: true)
                 .pluck(:posted_at, Arel.sql('favorite_count + retweet_count'))
                 .each { |posted_at, interactions| hourly_data[posted_at.hour] += interactions }
    end

    def calculate_peak_days
      return {} if tag_names.empty?

      daily_data = Hash.new(0)

      # Batch load posts with interactions
      load_facebook_daily_data(daily_data)
      load_twitter_daily_data(daily_data)

      # Convert to day names
      day_names = {
        0 => 'Domingo', 1 => 'Lunes', 2 => 'Martes', 3 => 'Miércoles',
        4 => 'Jueves', 5 => 'Viernes', 6 => 'Sábado'
      }

      daily_data.transform_keys { |k| day_names[k] }
    end

    def load_facebook_daily_data(daily_data)
      FacebookEntry.where(posted_at: @start_date..@end_date)
                   .tagged_with(tag_names, any: true)
                   .pluck(:posted_at, Arel.sql('reactions_total_count + comments_count + share_count'))
                   .each { |posted_at, interactions| daily_data[posted_at.wday] += interactions }
    end

    def load_twitter_daily_data(daily_data)
      TwitterPost.where(posted_at: @start_date..@end_date)
                 .tagged_with(tag_names, any: true)
                 .pluck(:posted_at, Arel.sql('favorite_count + retweet_count'))
                 .each { |posted_at, interactions| daily_data[posted_at.wday] += interactions }
    end

    def recommend_publishing_times
      peak_hours = calculate_peak_hours
      return { morning: '9:00', afternoon: '15:00', evening: '20:00' } if peak_hours.empty?

      top_hours = peak_hours.sort_by { |_k, v| -v }.first(3).map(&:first)

      {
        primary: "#{top_hours[0]}:00 - #{top_hours[0]}:59",
        secondary: "#{top_hours[1]}:00 - #{top_hours[1]}:59",
        tertiary: "#{top_hours[2]}:00 - #{top_hours[2]}:59",
        recommendation: generate_time_recommendation(top_hours)
      }
    end

    def generate_time_recommendation(top_hours)
      if top_hours.all? { |h| h.between?(6, 12) }
        "Tu audiencia es más activa en las mañanas. Publica entre 6:00 y 12:00."
      elsif top_hours.all? { |h| h.between?(12, 18) }
        "Tu audiencia es más activa en las tardes. Publica entre 12:00 y 18:00."
      elsif top_hours.all? { |h| h >= 18 || h < 6 }
        "Tu audiencia es más activa en las noches. Publica después de las 18:00."
      else
        "Tu audiencia está activa en diferentes momentos. Los mejores horarios son #{top_hours[0]}:00, #{top_hours[1]}:00 y #{top_hours[2]}:00."
      end
    end

    # ========================================
    # PHASE 2: COMPETITIVE INTELLIGENCE
    # ========================================

    def calculate_competitive_intelligence
      {
        share_of_voice: calculate_share_of_voice,
        market_position: calculate_market_position,
        growth_comparison: calculate_growth_comparison,
        competitive_topics: identify_competitive_topics
      }
    end

    def calculate_share_of_voice
      stats_by_topic = load_topic_stats_batch
      
      total_mentions = stats_by_topic.values.flatten.sum { |s| s.entry_count || 0 }
      return {} if total_mentions.zero?

      @topics.each_with_object({}) do |topic, hash|
        topic_mentions = (stats_by_topic[topic.id] || []).sum { |s| s.entry_count || 0 }
        
        hash[topic.name] = {
          mentions: topic_mentions,
          percentage: safe_percentage(topic_mentions, total_mentions, decimals: 1)
        }
      end
    end

    def calculate_market_position
      stats_by_topic = load_topic_stats_batch

      ranked_topics = @topics.map do |topic|
        interactions = (stats_by_topic[topic.id] || []).sum { |s| s.total_count || 0 }
        [topic, interactions]
      end.sort_by { |_topic, interactions| -interactions }

      total_interactions = ranked_topics.sum { |_t, i| i }

      ranked_topics.each_with_index.map do |(topic, interactions), index|
        {
          rank: index + 1,
          topic: topic.name,
          interactions: interactions,
          share: safe_percentage(interactions, total_interactions, decimals: 1)
        }
      end
    end

    def calculate_growth_comparison
      stats_by_topic = load_topic_stats_batch
      previous_stats_by_topic = load_previous_topic_stats_batch

      @topics.each_with_object({}) do |topic, hash|
        current_period = (stats_by_topic[topic.id] || []).sum { |s| s.entry_count || 0 }
        previous_period = (previous_stats_by_topic[topic.id] || []).sum { |s| s.entry_count || 0 }
        growth = safe_percentage(current_period - previous_period, previous_period, decimals: 1)

        hash[topic.name] = {
          current: current_period,
          previous: previous_period,
          growth: growth,
          trending: categorize_growth(growth)
        }
      end
    end

    def load_previous_topic_stats_batch
      TopicStatDaily.where(
        topic_id: @topics.map(&:id),
        topic_date: (@start_date - @days_range.days).to_date..@start_date.to_date
      ).group_by(&:topic_id)
    end

    def categorize_growth(growth)
      if growth > GROWTH_THRESHOLD
        'up'
      elsif growth < -GROWTH_THRESHOLD
        'down'
      else
        'stable'
      end
    end

    def identify_competitive_topics
      sov = calculate_share_of_voice
      
      # Topics with > 15% SOV are competitive
      competitive = sov.select { |_name, data| data[:percentage] > COMPETITIVE_SOV_THRESHOLD }

      competitive.map do |name, data|
        {
          topic: name,
          share: data[:percentage],
          status: categorize_competitive_status(data[:percentage])
        }
      end
    end

    def categorize_competitive_status(percentage)
      if percentage > DOMINANT_SOV_THRESHOLD
        'dominant'
      elsif percentage > STRONG_SOV_THRESHOLD
        'strong'
      else
        'competitive'
      end
    end

    # ========================================
    # HELPER METHODS
    # ========================================

    def safe_percentage(numerator, denominator, decimals: 0)
      return 0 if denominator.zero?
      (numerator.to_f / denominator * 100).round(decimals)
    end

    def calculate_trend_velocity(current, previous)
      safe_percentage(current - previous, previous, decimals: 1)
    end

    def calculate_trend_percent(current, previous)
      safe_percentage(current - previous, previous, decimals: 1)
    end
  end
end

# frozen_string_literal: true

module GeneralDashboardServices
  # Professional aggregation service for CEO-level reporting
  # Combines data from all sources: Digital Media, Facebook, Twitter
  # Following best practices from PR Analytics research (2024-2025)
  class AggregatorService < ApplicationService
    attr_reader :topic, :start_date, :end_date

    def initialize(topic:, start_date: DAYS_RANGE.days.ago.beginning_of_day, end_date: Time.zone.now.end_of_day)
      @topic = topic
      @start_date = start_date
      @end_date = end_date
    end

    def call
      Rails.cache.fetch(cache_key, expires_in: 30.minutes) do
        {
          executive_summary: build_executive_summary,
          channel_performance: build_channel_performance,
          temporal_intelligence: build_temporal_intelligence_lightweight,
          sentiment_analysis: build_sentiment_analysis,
          reach_analysis: build_reach_analysis,
          competitive_analysis: build_competitive_analysis,
          top_content: build_top_content,
          word_analysis: build_word_analysis_lightweight,
          recommendations: build_recommendations
        }
      end
    end

    private

    def cache_key
      "general_dashboard_#{topic.id}_#{start_date.to_date}_#{end_date.to_date}"
    end

    # ========================================
    # EXECUTIVE SUMMARY
    # ========================================
    def build_executive_summary
      {
        total_mentions: total_mentions,
        total_interactions: total_interactions,
        total_reach: total_reach,
        average_sentiment: average_sentiment,
        trend_velocity: overall_trend_velocity,
        share_of_voice: share_of_voice,
        engagement_rate: engagement_rate,
        period: {
          start: start_date,
          end: end_date,
          days: (end_date.to_date - start_date.to_date).to_i
        }
      }
    end

    # ========================================
    # CHANNEL PERFORMANCE
    # ========================================
    def build_channel_performance
      {
        digital: {
          name: 'Medios Digitales',
          icon: 'fa-newspaper',
          color: 'indigo',
          mentions: digital_data[:count],
          interactions: digital_data[:interactions],
          reach: digital_data[:reach],
          engagement_rate: calculate_engagement_rate(digital_data[:interactions], digital_data[:reach]),
          sentiment: digital_sentiment,
          trend: digital_data[:trend],
          share: calculate_share(digital_data[:count], total_mentions)
        },
        facebook: {
          name: 'Facebook',
          icon: 'fa-facebook',
          color: 'blue',
          mentions: facebook_data[:count],
          interactions: facebook_data[:interactions],
          reach: facebook_data[:reach],
          engagement_rate: calculate_engagement_rate(facebook_data[:interactions], facebook_data[:reach]),
          sentiment: facebook_sentiment,
          trend: facebook_data[:trend],
          share: calculate_share(facebook_data[:count], total_mentions)
        },
        twitter: {
          name: 'Twitter/X',
          icon: 'fa-twitter',
          color: 'sky',
          mentions: twitter_data[:count],
          interactions: twitter_data[:interactions],
          reach: twitter_data[:reach],
          engagement_rate: calculate_engagement_rate(twitter_data[:interactions], twitter_data[:reach]),
          sentiment: twitter_sentiment,
          trend: twitter_data[:trend],
          share: calculate_share(twitter_data[:count], total_mentions)
        }
      }
    end

    # ========================================
    # TEMPORAL INTELLIGENCE (Lightweight version)
    # ========================================
    def build_temporal_intelligence_lightweight
      {
        digital: nil, # Skip expensive calculations
        facebook: nil,
        twitter: nil,
        combined: {
          optimal_time: calculate_combined_optimal_time_simple,
          trend_velocity: overall_trend_velocity,
          engagement_velocity: overall_engagement_velocity,
          peak_hours: {},
          peak_days: {}
        }
      }
    end
    
    def calculate_combined_optimal_time_simple
      # Simple recommendation without expensive aggregations
      { day: 'Lunes', hour: 9, recommendation: 'Lunes a las 09:00 hrs', avg_engagement: 0 }
    end

    # ========================================
    # SENTIMENT ANALYSIS
    # ========================================
    def build_sentiment_analysis
      {
        overall: {
          score: average_sentiment,
          distribution: combined_sentiment_distribution,
          trend: sentiment_trend,
          confidence: overall_sentiment_confidence
        },
        by_channel: {
          digital: digital_sentiment_detail,
          facebook: facebook_sentiment_detail,
          twitter: twitter_sentiment_detail
        },
        alerts: detect_sentiment_alerts
      }
    end

    # ========================================
    # REACH ANALYSIS
    # ========================================
    def build_reach_analysis
      {
        total_reach: total_reach,
        by_channel: {
          digital: digital_data[:reach],
          facebook: facebook_data[:reach],
          twitter: twitter_data[:reach]
        },
        # estimated_impressions: total_impressions,  # REMOVED - Not defensible without tracking pixels
        unique_sources: unique_sources_count,
        geographic_distribution: geographic_distribution
      }
    end

    # ========================================
    # COMPETITIVE ANALYSIS
    # ========================================
    def build_competitive_analysis
      {
        share_of_voice: share_of_voice,
        market_position: market_position,
        growth_rate: growth_rate,
        comparison: {
          this_topic: {
            mentions: total_mentions,
            interactions: total_interactions
          },
          all_topics: {
            mentions: all_topics_mentions,
            interactions: all_topics_interactions
          },
          percentages: {
            mentions_share: calculate_share(total_mentions, all_topics_mentions),
            interactions_share: calculate_share(total_interactions, all_topics_interactions)
          }
        }
      }
    end

    # ========================================
    # TOP CONTENT
    # ========================================
    def build_top_content
      {
        top_entries: top_digital_entries,
        top_facebook_posts: top_facebook_posts,
        top_tweets: top_tweets,
        viral_content: identify_viral_content,
        trending_topics: trending_topics
      }
    end

    # ========================================
    # WORD ANALYSIS (Lightweight version)
    # ========================================
    def build_word_analysis_lightweight
      {
        top_words: [], # Skip expensive text processing
        top_bigrams: [],
        trending_terms: [],
        sentiment_words: {
          positive: topic.positive_words&.split(',') || [],
          negative: topic.negative_words&.split(',') || []
        }
      }
    end

    # ========================================
    # RECOMMENDATIONS (AI-powered insights)
    # ========================================
    def build_recommendations
      {
        best_publishing_time: best_publishing_time_recommendation,
        best_channel: best_channel_recommendation,
        content_suggestions: content_suggestions,
        sentiment_actions: sentiment_action_items,
        growth_opportunities: growth_opportunities
      }
    end

    # ========================================
    # HELPER METHODS - DATA COLLECTION
    # ========================================

    def digital_data
      @digital_data ||= begin
        entries = topic.report_entries(start_date, end_date)
        previous_entries = topic.report_entries(start_date - (end_date - start_date), start_date)
        
        # Reach estimation methodology:
        # Conservative 3x multiplier - assumes each interaction represents ~3 readers
        # This is defensible as a conservative estimate (much lower than typical 8-15x)
        # For precise reach, implement tracking pixels on news sites
        {
          count: entries.count,
          interactions: entries.sum(:total_count),
          reach: entries.sum(:total_count) * 3, # Conservative estimate
          trend: calculate_trend(entries.count, previous_entries.count)
        }
      end
    end

    def facebook_data
      @facebook_data ||= begin
        tag_names = topic.tags.pluck(:name)
        
        if tag_names.empty?
          return { count: 0, interactions: 0, reach: 0, trend: 0 }
        end
        
        # Efficient counting without loading all records
        entries_count = FacebookEntry
          .where(posted_at: start_date..end_date)
          .tagged_with(tag_names, any: true)
          .count('DISTINCT facebook_entries.id')
        
        previous_entries_count = FacebookEntry
          .where(posted_at: (start_date - (end_date - start_date))..start_date)
          .tagged_with(tag_names, any: true)
          .count('DISTINCT facebook_entries.id')
        
        # Calculate aggregates only if we have entries
        if entries_count > 0
          interactions = FacebookEntry
            .where(posted_at: start_date..end_date)
            .tagged_with(tag_names, any: true)
            .sum(Arel.sql('reactions_total_count + comments_count + share_count'))
          
          reach = FacebookEntry
            .where(posted_at: start_date..end_date)
            .tagged_with(tag_names, any: true)
            .sum(:views_count)
        else
          interactions = 0
          reach = 0
        end
        
        {
          count: entries_count,
          interactions: interactions,
          reach: reach,
          trend: calculate_trend(entries_count, previous_entries_count)
        }
      end
    end

    def twitter_data
      @twitter_data ||= begin
        tag_names = topic.tags.pluck(:name)
        
        if tag_names.empty?
          return { count: 0, interactions: 0, reach: 0, trend: 0 }
        end
        
        # Efficient counting without loading all records
        posts_count = TwitterPost
          .where(posted_at: start_date..end_date)
          .tagged_with(tag_names, any: true)
          .count('DISTINCT twitter_posts.id')
        
        previous_posts_count = TwitterPost
          .where(posted_at: (start_date - (end_date - start_date))..start_date)
          .tagged_with(tag_names, any: true)
          .count('DISTINCT twitter_posts.id')
        
        # Calculate aggregates only if we have posts
        if posts_count > 0
          interactions = TwitterPost
            .where(posted_at: start_date..end_date)
            .tagged_with(tag_names, any: true)
            .sum(Arel.sql('favorite_count + retweet_count + reply_count + quote_count'))
          
          views = TwitterPost
            .where(posted_at: start_date..end_date)
            .tagged_with(tag_names, any: true)
            .sum(:views_count)
          
          # Reach estimation: Use actual views when available, otherwise conservative 10x multiplier
          # 10x is conservative estimate (industry typical is 15-30x for Twitter)
          reach = views > 0 ? views : interactions * 10
        else
          interactions = 0
          reach = 0
        end
        
        {
          count: posts_count,
          interactions: interactions,
          reach: reach,
          trend: calculate_trend(posts_count, previous_posts_count)
        }
      end
    end

    def total_mentions
      digital_data[:count] + facebook_data[:count] + twitter_data[:count]
    end

    def total_interactions
      digital_data[:interactions] + facebook_data[:interactions] + twitter_data[:interactions]
    end

    def total_reach
      digital_data[:reach] + facebook_data[:reach] + twitter_data[:reach]
    end

    # REMOVED - Not a valid industry standard, cannot defend methodology
    # def total_impressions
    #   total_reach * 1.3 # This multiplier is arbitrary and not defensible
    # end

    # ========================================
    # SENTIMENT CALCULATIONS
    # ========================================

    def average_sentiment
      # Weighted average across all channels
      digital_score = digital_sentiment[:average] * digital_data[:count]
      facebook_score = facebook_sentiment[:average] * facebook_data[:count]
      twitter_score = twitter_sentiment[:average] * twitter_data[:count]
      
      total = digital_data[:count] + facebook_data[:count] + twitter_data[:count]
      return 0 if total.zero?
      
      ((digital_score + facebook_score + twitter_score) / total).round(2)
    end

    def digital_sentiment
      @digital_sentiment ||= begin
        entries = topic.report_entries(start_date, end_date)
        # Use size instead of count for tagged scopes
        positive = entries.where(polarity: :positive).size
        neutral = entries.where(polarity: :neutral).size
        negative = entries.where(polarity: :negative).size
        total = positive + neutral + negative
        
        {
          average: total.zero? ? 0 : ((positive - negative).to_f / total * 100).round(1),
          distribution: {
            positive: positive,
            neutral: neutral,
            negative: negative,
            positive_pct: total.zero? ? 0 : (positive.to_f / total * 100).round(1),
            neutral_pct: total.zero? ? 0 : (neutral.to_f / total * 100).round(1),
            negative_pct: total.zero? ? 0 : (negative.to_f / total * 100).round(1)
          }
        }
      end
    end

    def facebook_sentiment
      @facebook_sentiment ||= begin
        summary = topic.facebook_sentiment_summary(start_time: start_date, end_time: end_date)
        summary ? { average: summary[:average_sentiment], distribution: summary[:sentiment_distribution] } : { average: 0, distribution: {} }
      end
    end

    def twitter_sentiment
      # Twitter doesn't have sentiment yet, return neutral
      @twitter_sentiment ||= { average: 0, distribution: {} }
    end

    def digital_sentiment_detail
      digital_sentiment.merge(channel: 'digital')
    end

    def facebook_sentiment_detail
      facebook_sentiment.merge(channel: 'facebook')
    end

    def twitter_sentiment_detail
      twitter_sentiment.merge(channel: 'twitter')
    end

    def combined_sentiment_distribution
      dist = digital_sentiment[:distribution] || {}
      fb_dist = facebook_sentiment[:distribution] || {}
      
      {
        positive: (dist[:positive] || 0) + (fb_dist[:very_positive]&.[](:count) || 0) + (fb_dist[:positive]&.[](:count) || 0),
        neutral: (dist[:neutral] || 0) + (fb_dist[:neutral]&.[](:count) || 0),
        negative: (dist[:negative] || 0) + (fb_dist[:very_negative]&.[](:count) || 0) + (fb_dist[:negative]&.[](:count) || 0)
      }
    end

    def sentiment_trend
      current_sentiment = average_sentiment
      
      # Skip expensive previous period calculation for now
      # TODO: Optimize this with cached aggregates
      {
        current: current_sentiment,
        previous: 0,
        change: 0,
        direction: 'stable'
      }
    end

    def overall_sentiment_confidence
      # Based on sample size
      total = total_mentions
      case total
      when 0...10 then 0.2
      when 10...50 then 0.5
      when 50...200 then 0.7
      when 200...1000 then 0.85
      else 0.95
      end
    end

    def detect_sentiment_alerts
      alerts = []
      
      # Negative spike detection
      if average_sentiment < -30
        alerts << {
          type: 'crisis',
          severity: 'high',
          message: 'Sentimiento muy negativo detectado',
          recommendation: 'Revisar inmediatamente y preparar respuesta de crisis'
        }
      end
      
      # Rapid sentiment decline
      trend = sentiment_trend
      if trend[:change] < -20
        alerts << {
          type: 'warning',
          severity: 'medium',
          message: 'Rápida caída en el sentimiento',
          recommendation: 'Monitorear de cerca y considerar acción correctiva'
        }
      end
      
      # Highly positive trend
      if average_sentiment > 50 && trend[:direction] == 'improving'
        alerts << {
          type: 'opportunity',
          severity: 'low',
          message: 'Sentimiento muy positivo y en aumento',
          recommendation: 'Momento ideal para amplificar el mensaje'
        }
      end
      
      alerts
    end

    # ========================================
    # COMPETITIVE & MARKET ANALYSIS
    # ========================================

    def share_of_voice
      return 0 if all_topics_mentions.zero?
      (total_mentions.to_f / all_topics_mentions * 100).round(1)
    end

    def all_topics_mentions
      @all_topics_mentions ||= begin
        digital = Entry.enabled.where(published_at: start_date..end_date).count
        # Use count(:id) for Facebook and Twitter to avoid tagged_with issues
        facebook = FacebookEntry.where(posted_at: start_date..end_date).count(:id)
        twitter = TwitterPost.where(posted_at: start_date..end_date).count(:id)
        digital + facebook + twitter
      end
    end

    def all_topics_interactions
      @all_topics_interactions ||= begin
        digital = Entry.enabled.where(published_at: start_date..end_date).sum(:total_count)
        facebook = FacebookEntry.where(posted_at: start_date..end_date).sum(Arel.sql('reactions_total_count + comments_count + share_count'))
        twitter = TwitterPost.where(posted_at: start_date..end_date).sum(Arel.sql('favorite_count + retweet_count + reply_count + quote_count'))
        digital + facebook + twitter
      end
    end

    def market_position
      # Rank this topic against others
      all_topics = Topic.active
      ranked = all_topics.map do |t|
        service = self.class.new(topic: t, start_date: start_date, end_date: end_date)
        [t.id, service.send(:total_mentions)]
      end.sort_by { |_id, count| -count }
      
      position = ranked.index { |id, _count| id == topic.id }
      {
        rank: position ? position + 1 : nil,
        total_topics: ranked.size,
        percentile: position ? ((1 - position.to_f / ranked.size) * 100).round(0) : nil
      }
    end

    def growth_rate
      # Simplified growth calculation using trend velocities already calculated
      avg_trend = (digital_data[:trend] + facebook_data[:trend] + twitter_data[:trend]) / 3.0
      avg_trend.round(1)
    end

    # ========================================
    # TEMPORAL INTELLIGENCE
    # ========================================

    def calculate_combined_optimal_time
      digital_optimal = topic.optimal_publishing_time
      facebook_optimal = topic.facebook_optimal_publishing_time
      twitter_optimal = topic.twitter_optimal_publishing_time
      
      # Weight by engagement
      best = [digital_optimal, facebook_optimal, twitter_optimal]
               .compact
               .max_by { |opt| opt[:avg_engagement] }
      
      best || { day: 'Lunes', hour: 9, recommendation: 'Lunes a las 09:00 hrs' }
    end

    def combined_peak_hours
      # Aggregate peak hours across all channels
      digital_peaks = topic.peak_publishing_times_by_hour
      facebook_peaks = topic.facebook_peak_publishing_times_by_hour
      twitter_peaks = topic.twitter_peak_publishing_times_by_hour
      
      combined = {}
      [digital_peaks, facebook_peaks, twitter_peaks].each do |peaks|
        peaks.each do |hour, data|
          combined[hour] ||= { avg_engagement: 0, entry_count: 0 }
          combined[hour][:avg_engagement] += data[:avg_engagement]
          combined[hour][:entry_count] += data[:entry_count]
        end
      end
      
      combined.sort_by { |_hour, data| -data[:avg_engagement] }.first(3).to_h
    end

    def combined_peak_days
      # Aggregate peak days across all channels
      digital_peaks = topic.peak_publishing_times_by_day
      facebook_peaks = topic.facebook_peak_publishing_times_by_day
      twitter_peaks = topic.twitter_peak_publishing_times_by_day
      
      combined = {}
      [digital_peaks, facebook_peaks, twitter_peaks].each do |peaks|
        peaks.each do |day, data|
          combined[day] ||= { avg_engagement: 0, entry_count: 0 }
          combined[day][:avg_engagement] += data[:avg_engagement]
          combined[day][:entry_count] += data[:entry_count]
        end
      end
      
      combined.sort_by { |_day, data| -data[:avg_engagement] }.first(3).to_h
    end

    def overall_trend_velocity
      digital_trend = topic.trend_velocity[:velocity_percent] rescue 0
      facebook_trend = topic.facebook_trend_velocity[:velocity_percent] rescue 0
      twitter_trend = topic.twitter_trend_velocity[:velocity_percent] rescue 0
      
      avg = ((digital_trend + facebook_trend + twitter_trend) / 3.0).round(1)
      
      {
        velocity_percent: avg,
        direction: avg > 0 ? 'up' : (avg < 0 ? 'down' : 'stable'),
        trend: avg > 10 ? 'creciendo' : (avg < -10 ? 'decreciendo' : 'estable')
      }
    end

    def overall_engagement_velocity
      digital_eng = topic.engagement_velocity[:velocity_percent] rescue 0
      facebook_eng = topic.facebook_engagement_velocity[:velocity_percent] rescue 0
      twitter_eng = topic.twitter_engagement_velocity[:velocity_percent] rescue 0
      
      avg = ((digital_eng + facebook_eng + twitter_eng) / 3.0).round(1)
      
      {
        velocity_percent: avg,
        direction: avg > 0 ? 'up' : (avg < 0 ? 'down' : 'stable'),
        trend: avg > 15 ? 'alto' : (avg < -15 ? 'bajo' : 'moderado')
      }
    end

    # ========================================
    # CONTENT ANALYSIS
    # ========================================

    def top_digital_entries
      topic.report_entries(start_date, end_date)
           .order(total_count: :desc)
           .limit(5)
           .includes(:site) # Eager load to avoid N+1
    end

    def top_facebook_posts
      tag_names = topic.tags.pluck(:name)
      return FacebookEntry.none if tag_names.empty?
      
      FacebookEntry.where(posted_at: start_date..end_date)
                   .tagged_with(tag_names, any: true)
                   .order(Arel.sql('reactions_total_count + comments_count + share_count DESC'))
                   .limit(5)
                   .includes(:page) # Eager load to avoid N+1
    end

    def top_tweets
      tag_names = topic.tags.pluck(:name)
      return TwitterPost.none if tag_names.empty?
      
      TwitterPost.where(posted_at: start_date..end_date)
                 .tagged_with(tag_names, any: true)
                 .order(Arel.sql('favorite_count + retweet_count + reply_count + quote_count DESC'))
                 .limit(5)
                 .includes(:twitter_profile) # Eager load to avoid N+1
    end

    def identify_viral_content
      # Content with exceptionally high engagement
      {
        digital: identify_viral_digital,
        facebook: identify_viral_facebook,
        twitter: identify_viral_twitter
      }
    end
    
    def identify_viral_digital
      return [] if digital_data[:count].zero?
      
      avg_engagement = digital_data[:interactions] / digital_data[:count].to_f
      threshold = avg_engagement * 5
      
      top_digital_entries.select { |e| e.total_count > threshold }
    end
    
    def identify_viral_facebook
      return [] if facebook_data[:count].zero?
      
      avg_engagement = facebook_data[:interactions] / facebook_data[:count].to_f
      threshold = avg_engagement * 5
      
      top_facebook_posts.select do |p|
        (p.reactions_total_count + p.comments_count + p.share_count) > threshold
      end
    end
    
    def identify_viral_twitter
      return [] if twitter_data[:count].zero?
      
      avg_engagement = twitter_data[:interactions] / twitter_data[:count].to_f
      threshold = avg_engagement * 5
      
      top_tweets.select { |t| t.total_interactions > threshold }
    end

    def trending_topics
      # Get tag distribution
      topic.tags.pluck(:name)
    end

    def combined_word_occurrences
      digital_words = topic.report_entries(start_date, end_date).word_occurrences(50)
      facebook_words = FacebookEntry.word_occurrences(FacebookEntry.for_topic(topic, start_time: start_date, end_time: end_date), 50)
      twitter_words = TwitterPost.word_occurrences(TwitterPost.for_topic(topic, start_time: start_date, end_time: end_date), 50)
      
      merge_word_occurrences([digital_words, facebook_words, twitter_words])
    end

    def combined_bigram_occurrences
      digital_bigrams = topic.report_entries(start_date, end_date).bigram_occurrences(50)
      facebook_bigrams = FacebookEntry.bigram_occurrences(FacebookEntry.for_topic(topic, start_time: start_date, end_time: end_date), 50)
      twitter_bigrams = TwitterPost.bigram_occurrences(TwitterPost.for_topic(topic, start_time: start_date, end_time: end_date), 50)
      
      merge_word_occurrences([digital_bigrams, facebook_bigrams, twitter_bigrams])
    end

    def trending_terms
      # Words that appeared significantly more in recent period
      current_words = combined_word_occurrences.first(20).to_h
      
      # Compare with previous period
      previous_service = self.class.new(
        topic: topic,
        start_date: start_date - (end_date - start_date),
        end_date: start_date
      )
      
      begin
        previous_words = previous_service.send(:combined_word_occurrences).to_h
        
        trending = current_words.select do |word, count|
          prev_count = previous_words[word] || 0
          count > prev_count * 1.5 # 50% increase
        end
        
        trending.sort_by { |_word, count| -count }.first(10)
      rescue StandardError
        current_words.first(10)
      end
    end

    # ========================================
    # RECOMMENDATIONS
    # ========================================

    def best_publishing_time_recommendation
      optimal = calculate_combined_optimal_time
      {
        recommendation: optimal[:recommendation],
        reasoning: "Basado en análisis de engagement promedio más alto (#{optimal[:avg_engagement].round(1)}) en #{optimal[:day]} a las #{optimal[:hour]}:00"
      }
    end

    def best_channel_recommendation
      channels = build_channel_performance
      best = channels.max_by { |_key, data| data[:engagement_rate] }
      
      {
        channel: best[1][:name],
        reasoning: "#{best[1][:name]} tiene la tasa de engagement más alta (#{best[1][:engagement_rate]}%)"
      }
    end

    def content_suggestions
      suggestions = []
      
      # Based on viral content
      if identify_viral_content.values.any?(&:any?)
        suggestions << {
          type: 'content_type',
          suggestion: 'Crear más contenido similar al que ha generado mayor engagement',
          priority: 'high'
        }
      end
      
      # Based on sentiment
      if average_sentiment < 0
        suggestions << {
          type: 'sentiment',
          suggestion: 'Incorporar mensajes más positivos y soluciones en el contenido',
          priority: 'high'
        }
      end
      
      # Based on trending terms
      if trending_terms.any?
        top_term = trending_terms.first[0]
        suggestions << {
          type: 'trending',
          suggestion: "Aprovechar la tendencia de '#{top_term}' en futuras publicaciones",
          priority: 'medium'
        }
      end
      
      suggestions
    end

    def sentiment_action_items
      actions = []
      alerts = detect_sentiment_alerts
      
      alerts.each do |alert|
        actions << {
          action: alert[:recommendation],
          priority: alert[:severity],
          reason: alert[:message]
        }
      end
      
      actions
    end

    def growth_opportunities
      opportunities = []
      
      # Underperforming channels
      channels = build_channel_performance
      avg_engagement = channels.values.map { |c| c[:engagement_rate] }.sum / channels.size
      
      channels.each do |key, data|
        if data[:engagement_rate] < avg_engagement * 0.7
          opportunities << {
            area: data[:name],
            current: "#{data[:engagement_rate]}% engagement",
            potential: "Objetivo: #{avg_engagement.round(1)}% engagement",
            suggestion: "Optimizar estrategia en #{data[:name]}"
          }
        end
      end
      
      # Low share of voice
      if share_of_voice < 20
        opportunities << {
          area: 'Share of Voice',
          current: "#{share_of_voice}%",
          potential: "Objetivo: 25-30%",
          suggestion: 'Aumentar frecuencia y visibilidad de publicaciones'
        }
      end
      
      opportunities
    end

    # ========================================
    # UTILITY METHODS
    # ========================================

    def calculate_trend(current, previous)
      return 0 if previous.zero?
      ((current - previous).to_f / previous * 100).round(1)
    end

    def calculate_share(part, whole)
      return 0 if whole.zero?
      (part.to_f / whole * 100).round(1)
    end

    def calculate_engagement_rate(interactions, reach)
      return 0 if reach.zero?
      (interactions.to_f / reach * 100).round(2)
    end

    def engagement_rate
      calculate_engagement_rate(total_interactions, total_reach)
    end

    def unique_sources_count
      # Optimized counting with DISTINCT at database level
      tag_names = topic.tags.pluck(:name)
      return 0 if tag_names.empty?
      
      digital_sources = topic.report_entries(start_date, end_date)
                            .joins(:site)
                            .distinct
                            .count('DISTINCT sites.id')
      
      facebook_sources = FacebookEntry.where(posted_at: start_date..end_date)
                                      .tagged_with(tag_names, any: true)
                                      .joins(:page)
                                      .count('DISTINCT pages.id')
      
      twitter_sources = TwitterPost.where(posted_at: start_date..end_date)
                                   .tagged_with(tag_names, any: true)
                                   .joins(:twitter_profile)
                                   .count('DISTINCT twitter_profiles.id')
      
      digital_sources + facebook_sources + twitter_sources
    end

    def geographic_distribution
      # Placeholder - would need geographic data
      {}
    end

    def merge_word_occurrences(word_arrays)
      combined = Hash.new(0)
      word_arrays.each do |words|
        words.each do |word, count|
          combined[word] += count
        end
      end
      combined.sort_by { |_word, count| -count }.first(100)
    end
  end
end


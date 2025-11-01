# frozen_string_literal: true

module HomeServices
  class DashboardAggregatorService < ApplicationService
    def initialize(topics:, days_range: DAYS_RANGE)
      @topics = topics
      @days_range = days_range
      @start_date = days_range.days.ago.beginning_of_day
      @end_date = Time.current
    end

    def call
      Rails.cache.fetch(cache_key, expires_in: 30.minutes) do
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

    # EXECUTIVE SUMMARY
    def calculate_executive_summary
      digital_stats = digital_channel_stats
      facebook_stats = facebook_channel_stats
      twitter_stats = twitter_channel_stats

      total_mentions = digital_stats[:mentions] + facebook_stats[:mentions] + twitter_stats[:mentions]
      total_interactions = digital_stats[:interactions] + facebook_stats[:interactions] + twitter_stats[:interactions]
      total_reach = digital_stats[:reach] + facebook_stats[:reach] + twitter_stats[:reach]

      # Calculate weighted average sentiment
      avg_sentiment = calculate_weighted_sentiment

      # Calculate previous period for comparison
      previous_interactions = calculate_previous_period_interactions

      {
        total_mentions: total_mentions,
        total_interactions: total_interactions,
        total_reach: total_reach,
        average_sentiment: avg_sentiment,
        engagement_rate: total_reach > 0 ? (total_interactions.to_f / total_reach * 100) : 0,
        trend_velocity: calculate_trend_velocity(total_interactions, previous_interactions),
        period: {
          days: @days_range,
          start: @start_date,
          end: @end_date
        }
      }
    end

    # CHANNEL STATISTICS
    def calculate_channel_stats
      digital = digital_channel_stats
      facebook = facebook_channel_stats
      twitter = twitter_channel_stats

      total_mentions = digital[:mentions] + facebook[:mentions] + twitter[:mentions]

      {
        digital: digital.merge(
          share: total_mentions > 0 ? (digital[:mentions].to_f / total_mentions * 100).round(1) : 0,
          color: 'indigo',
          name: 'Medios Digitales',
          icon: 'fa-solid fa-newspaper'
        ),
        facebook: facebook.merge(
          share: total_mentions > 0 ? (facebook[:mentions].to_f / total_mentions * 100).round(1) : 0,
          color: 'blue',
          name: 'Facebook',
          icon: 'fa-brands fa-facebook'
        ),
        twitter: twitter.merge(
          share: total_mentions > 0 ? (twitter[:mentions].to_f / total_mentions * 100).round(1) : 0,
          color: 'sky',
          name: 'Twitter',
          icon: 'fa-brands fa-twitter'
        )
      }
    end

    def digital_channel_stats
      tag_names = @topics.map { |t| t.tags.pluck(:name) }.flatten.uniq

      return zero_stats if tag_names.empty?

      # Calculate each metric independently with fresh queries
      mentions = Entry.enabled
                      .where(published_at: @start_date..@end_date)
                      .tagged_with(tag_names, any: true)
                      .count('DISTINCT entries.id')
      
      interactions = Entry.enabled
                          .where(published_at: @start_date..@end_date)
                          .tagged_with(tag_names, any: true)
                          .sum(:total_count)
      
      reach = interactions * 3 # Conservative 3x multiplier for digital media

      # Calculate previous period for trend
      prev_interactions = Entry.enabled
                               .where(published_at: (@start_date - @days_range.days)..@start_date)
                               .tagged_with(tag_names, any: true)
                               .sum(:total_count)

      # Calculate sentiment with independent queries
      sentiment = calculate_digital_sentiment(tag_names)

      {
        mentions: mentions,
        interactions: interactions,
        reach: reach,
        engagement_rate: reach > 0 ? (interactions.to_f / reach * 100).round(2) : 0,
        trend: calculate_trend_percent(interactions, prev_interactions),
        sentiment: sentiment
      }
    end

    def facebook_channel_stats
      tag_names = @topics.map { |t| t.tags.pluck(:name) }.flatten.uniq

      return zero_stats if tag_names.empty?

      # Calculate each metric independently with fresh queries
      mentions = FacebookEntry.where(posted_at: @start_date..@end_date)
                              .tagged_with(tag_names, any: true)
                              .count('DISTINCT facebook_entries.id')
      
      interactions = FacebookEntry.where(posted_at: @start_date..@end_date)
                                  .tagged_with(tag_names, any: true)
                                  .sum(Arel.sql('reactions_total_count + comments_count + share_count'))
      
      reach = FacebookEntry.where(posted_at: @start_date..@end_date)
                           .tagged_with(tag_names, any: true)
                           .sum(:views_count) # Actual API data

      # Previous period for trend
      prev_interactions = FacebookEntry.where(posted_at: (@start_date - @days_range.days)..@start_date)
                                      .tagged_with(tag_names, any: true)
                                      .sum(Arel.sql('reactions_total_count + comments_count + share_count'))

      # Calculate sentiment with tag_names
      sentiment = calculate_facebook_sentiment(tag_names)

      {
        mentions: mentions,
        interactions: interactions,
        reach: reach,
        engagement_rate: reach > 0 ? (interactions.to_f / reach * 100).round(2) : 0,
        trend: calculate_trend_percent(interactions, prev_interactions),
        sentiment: sentiment
      }
    end

    def twitter_channel_stats
      tag_names = @topics.map { |t| t.tags.pluck(:name) }.flatten.uniq

      return zero_stats if tag_names.empty?

      # Calculate each metric independently with fresh queries
      mentions = TwitterPost.where(posted_at: @start_date..@end_date)
                            .tagged_with(tag_names, any: true)
                            .count('DISTINCT twitter_posts.id')
      
      interactions = TwitterPost.where(posted_at: @start_date..@end_date)
                                .tagged_with(tag_names, any: true)
                                .sum(Arel.sql('favorite_count + retweet_count + reply_count + quote_count'))

      # Twitter reach: use views_count when available, fallback to 10x interactions
      views = TwitterPost.where(posted_at: @start_date..@end_date)
                         .tagged_with(tag_names, any: true)
                         .sum(:views_count)
      reach = views > 0 ? views : interactions * 10

      # Previous period for trend
      prev_interactions = TwitterPost.where(posted_at: (@start_date - @days_range.days)..@start_date)
                                     .tagged_with(tag_names, any: true)
                                     .sum(Arel.sql('favorite_count + retweet_count + reply_count + quote_count'))

      {
        mentions: mentions,
        interactions: interactions,
        reach: reach,
        engagement_rate: reach > 0 ? (interactions.to_f / reach * 100).round(2) : 0,
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

    # TOPIC STATISTICS
    def calculate_topic_stats
      @topics.each_with_object({}) do |topic, hash|
        stats = topic.topic_stat_dailies
                     .where(topic_date: @start_date.to_date..@end_date.to_date)

        mentions = stats.sum(:entry_count)
        interactions = stats.sum(:total_count)

        hash[topic.id] = {
          mentions: mentions,
          interactions: interactions,
          sentiment: calculate_topic_sentiment_score(topic),
          trend_direction: calculate_topic_trend_direction(topic)
        }
      end
    end

    def calculate_topic_trends
      @topics.each_with_object({}) do |topic, hash|
        daily_data = topic.topic_stat_dailies
                          .where(topic_date: @start_date.to_date..@end_date.to_date)
                          .order(:topic_date)
                          .pluck(:topic_date, :entry_count)
                          .to_h

        hash[topic.id] = {
          data: daily_data,
          direction: calculate_topic_trend_direction(topic)
        }
      end
    end

    def calculate_topic_sentiment_score(topic)
      stats = topic.topic_stat_dailies
                   .where(topic_date: @start_date.to_date..@end_date.to_date)

      total = stats.sum(:positive_quantity) + stats.sum(:neutral_quantity) + stats.sum(:negative_quantity)
      return 0 if total.zero?

      positive = stats.sum(:positive_quantity)
      negative = stats.sum(:negative_quantity)

      # Return score from -100 to +100
      ((positive - negative).to_f / total * 100).round(1)
    end

    def calculate_topic_trend_direction(topic)
      recent_count = topic.topic_stat_dailies
                          .where(topic_date: 3.days.ago.to_date..@end_date.to_date)
                          .sum(:entry_count)

      previous_count = topic.topic_stat_dailies
                            .where(topic_date: 6.days.ago.to_date..3.days.ago.to_date)
                            .sum(:entry_count)

      return 'stable' if recent_count == previous_count || previous_count.zero?

      recent_count > previous_count ? 'up' : 'down'
    end

    # ALERTS
    def generate_alerts
      alerts = []

      @topics.each do |topic|
        sentiment = calculate_topic_sentiment_score(topic)

        # Critical negative sentiment alert
        if sentiment < -40
          alerts << {
            severity: 'high',
            type: 'crisis',
            message: "⚠️ Crisis de Reputación: #{topic.name}",
            details: "Sentimiento muy negativo detectado (#{sentiment.round(1)}%). Requiere atención inmediata.",
            topic: topic.name,
            url: Rails.application.routes.url_helpers.topic_path(topic)
          }
        elsif sentiment < -20
          alerts << {
            severity: 'medium',
            type: 'warning',
            message: "⚡ Alerta de Sentimiento: #{topic.name}",
            details: "Tendencia negativa en menciones (#{sentiment.round(1)}%). Monitorear de cerca.",
            topic: topic.name,
            url: Rails.application.routes.url_helpers.topic_path(topic)
          }
        end

        # Declining mentions alert
        trend_direction = calculate_topic_trend_direction(topic)
        if trend_direction == 'down'
          recent_count = topic.topic_stat_dailies
                              .where(topic_date: 3.days.ago.to_date..@end_date.to_date)
                              .sum(:entry_count)

          if recent_count > 10 # Only alert if there's meaningful data
            alerts << {
              severity: 'low',
              type: 'info',
              message: "📉 Disminución de Menciones: #{topic.name}",
              details: "Las menciones están disminuyendo en los últimos días. Considere aumentar actividad.",
              topic: topic.name,
              url: Rails.application.routes.url_helpers.topic_path(topic)
            }
          end
        end
      end

      alerts.sort_by { |a| ['high', 'medium', 'low'].index(a[:severity]) }
    end

    # TOP CONTENT
    def fetch_top_content
      tag_names = @topics.map { |t| t.tags.pluck(:name) }.flatten.uniq

      {
        top_entries: fetch_top_digital_entries(tag_names),
        top_facebook_posts: fetch_top_facebook_posts(tag_names),
        top_tweets: fetch_top_tweets(tag_names)
      }
    end

    def fetch_top_digital_entries(tag_names)
      return Entry.none if tag_names.empty?

      Entry.enabled
           .where(published_at: @start_date..@end_date)
           .tagged_with(tag_names, any: true)
           .includes(:site)
           .order(Arel.sql('total_count DESC'))
           .limit(5)
    end

    def fetch_top_facebook_posts(tag_names)
      return FacebookEntry.none if tag_names.empty?

      FacebookEntry.where(posted_at: @start_date..@end_date)
                   .tagged_with(tag_names, any: true)
                   .includes(:page)
                   .order(Arel.sql('reactions_total_count + comments_count + share_count DESC'))
                   .limit(5)
    end

    def fetch_top_tweets(tag_names)
      return TwitterPost.none if tag_names.empty?

      TwitterPost.where(posted_at: @start_date..@end_date)
                 .tagged_with(tag_names, any: true)
                 .includes(:twitter_profile)
                 .order(Arel.sql('favorite_count + retweet_count + reply_count + quote_count DESC'))
                 .limit(5)
    end

    # HELPER CALCULATIONS
    def calculate_weighted_sentiment
      digital_stats = digital_channel_stats
      facebook_stats = facebook_channel_stats
      twitter_stats = twitter_channel_stats

      total_mentions = digital_stats[:mentions] + facebook_stats[:mentions] + twitter_stats[:mentions]
      return 0 if total_mentions.zero?

      weighted_sum = (digital_stats[:sentiment] * digital_stats[:mentions]) +
                     (facebook_stats[:sentiment] * facebook_stats[:mentions]) +
                     (twitter_stats[:sentiment] * twitter_stats[:mentions])

      (weighted_sum / total_mentions).round(1)
    end

    def calculate_digital_sentiment(tag_names)
      # Return 0 if no tags to search for
      return 0 if tag_names.empty?

      # Build completely independent queries for each count
      # Use basic count (not count with DISTINCT) after tagged_with
      positive = Entry.enabled
                      .where(published_at: @start_date..@end_date)
                      .where(polarity: :positive)
                      .tagged_with(tag_names, any: true)
                      .size
      
      negative = Entry.enabled
                      .where(published_at: @start_date..@end_date)
                      .where(polarity: :negative)
                      .tagged_with(tag_names, any: true)
                      .size
      
      total = Entry.enabled
                   .where(published_at: @start_date..@end_date)
                   .tagged_with(tag_names, any: true)
                   .size

      return 0 if total.zero?

      ((positive - negative).to_f / total * 100).round(1)
    end

    def calculate_facebook_sentiment(tag_names)
      # Return 0 if no tags to search for
      return 0 if tag_names.empty?

      # Build completely independent queries
      total_score = FacebookEntry.where(posted_at: @start_date..@end_date)
                                 .tagged_with(tag_names, any: true)
                                 .sum(:sentiment_score)
      
      count = FacebookEntry.where(posted_at: @start_date..@end_date)
                           .where.not(sentiment_score: nil)
                           .tagged_with(tag_names, any: true)
                           .size

      return 0 if count.zero?

      # Convert FacebookEntry sentiment_score (-2.0 to +2.0) to percentage (-100 to +100)
      (total_score / count * 50).round(1)
    end

    def calculate_previous_period_interactions
      digital_stats = previous_digital_interactions
      facebook_stats = previous_facebook_interactions
      twitter_stats = previous_twitter_interactions

      digital_stats + facebook_stats + twitter_stats
    end

    def previous_digital_interactions
      tag_names = @topics.map { |t| t.tags.pluck(:name) }.flatten.uniq
      return 0 if tag_names.empty?

      Entry.enabled
           .where(published_at: (@start_date - @days_range.days)..@start_date)
           .tagged_with(tag_names, any: true)
           .sum(:total_count)
    end

    def previous_facebook_interactions
      tag_names = @topics.map { |t| t.tags.pluck(:name) }.flatten.uniq
      return 0 if tag_names.empty?

      FacebookEntry.where(posted_at: (@start_date - @days_range.days)..@start_date)
                   .tagged_with(tag_names, any: true)
                   .sum(Arel.sql('reactions_total_count + comments_count + share_count'))
    end

    def previous_twitter_interactions
      tag_names = @topics.map { |t| t.tags.pluck(:name) }.flatten.uniq
      return 0 if tag_names.empty?

      TwitterPost.where(posted_at: (@start_date - @days_range.days)..@start_date)
                 .tagged_with(tag_names, any: true)
                 .sum(Arel.sql('favorite_count + retweet_count + reply_count + quote_count'))
    end

    def calculate_trend_velocity(current, previous)
      return 0 if previous.zero?

      ((current - previous).to_f / previous * 100).round(1)
    end

    def calculate_trend_percent(current, previous)
      return 0 if previous.zero?

      ((current - previous).to_f / previous * 100).round(1)
    end

    # ========================================
    # PHASE 2: ENHANCED ANALYTICS
    # ========================================

    # SENTIMENT INTELLIGENCE CENTER
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
      # Get daily sentiment scores for the period
      daily_scores = {}
      
      (@start_date.to_date..@end_date.to_date).each do |date|
        tag_names = @topics.map { |t| t.tags.pluck(:name) }.flatten.uniq
        next if tag_names.empty?

        # Calculate daily sentiment from topic_stat_dailies
        positive = @topics.sum { |t| t.topic_stat_dailies.where(topic_date: date).sum(:positive_quantity) }
        negative = @topics.sum { |t| t.topic_stat_dailies.where(topic_date: date).sum(:negative_quantity) }
        neutral = @topics.sum { |t| t.topic_stat_dailies.where(topic_date: date).sum(:neutral_quantity) }
        
        total = positive + negative + neutral
        score = total > 0 ? ((positive - negative).to_f / total * 100).round(1) : 0
        
        daily_scores[date.strftime('%Y-%m-%d')] = score
      end

      daily_scores
    end

    def sentiment_by_topic
      @topics.each_with_object({}) do |topic, hash|
        stats = topic.topic_stat_dailies
                     .where(topic_date: @start_date.to_date..@end_date.to_date)

        positive = stats.sum(:positive_quantity)
        negative = stats.sum(:negative_quantity)
        total = positive + stats.sum(:neutral_quantity) + negative

        hash[topic.name] = total > 0 ? ((positive - negative).to_f / total * 100).round(1) : 0
      end
    end

    def sentiment_by_channel
      {
        digital: digital_channel_stats[:sentiment],
        facebook: facebook_channel_stats[:sentiment],
        twitter: twitter_channel_stats[:sentiment]
      }
    end

    def find_controversial_content
      tag_names = @topics.map { |t| t.tags.pluck(:name) }.flatten.uniq
      return [] if tag_names.empty?

      # Find Facebook posts with high controversy index
      controversial_fb = FacebookEntry.where(posted_at: @start_date..@end_date)
                                      .tagged_with(tag_names, any: true)
                                      .where('controversy_index > ?', 0.6)
                                      .order(controversy_index: :desc)
                                      .limit(5)
                                      .includes(:page)

      controversial_fb.map do |post|
        {
          type: 'facebook',
          title: post.message&.truncate(80) || 'Ver publicación',
          url: post.permalink_url,
          source: post.page.name,
          controversy_index: post.controversy_index.round(2),
          reactions: post.reactions_total_count
        }
      end
    end

    def calculate_sentiment_confidence
      tag_names = @topics.map { |t| t.tags.pluck(:name) }.flatten.uniq
      return { confidence: 0, sample_size: 0, reliability: 'very_low' } if tag_names.empty?

      # Count total sentiment-analyzed content
      digital_count = Entry.enabled
                           .where(published_at: @start_date..@end_date)
                           .tagged_with(tag_names, any: true)
                           .size

      facebook_count = FacebookEntry.where(posted_at: @start_date..@end_date)
                                    .tagged_with(tag_names, any: true)
                                    .where.not(sentiment_score: nil)
                                    .size

      total_sample = digital_count + facebook_count

      # Calculate confidence based on sample size
      confidence = case total_sample
                   when 0...10 then 0.20
                   when 10...50 then 0.50
                   when 50...200 then 0.70
                   when 200...1000 then 0.85
                   else 0.95
                   end

      reliability = case confidence
                    when 0...0.3 then 'very_low'
                    when 0.3...0.5 then 'low'
                    when 0.5...0.7 then 'moderate'
                    when 0.7...0.9 then 'good'
                    else 'high'
                    end

      {
        confidence: confidence,
        sample_size: total_sample,
        reliability: reliability
      }
    end

    # TEMPORAL INTELLIGENCE
    def calculate_temporal_intelligence
      {
        peak_hours: calculate_peak_hours,
        peak_days: calculate_peak_days,
        best_publishing_times: recommend_publishing_times
      }
    end

    def calculate_peak_hours
      tag_names = @topics.map { |t| t.tags.pluck(:name) }.flatten.uniq
      return {} if tag_names.empty?

      # Aggregate posts by hour of day
      hourly_data = Hash.new(0)

      # Facebook posts by hour
      FacebookEntry.where(posted_at: @start_date..@end_date)
                   .tagged_with(tag_names, any: true)
                   .pluck(:posted_at, Arel.sql('reactions_total_count + comments_count + share_count'))
                   .each do |posted_at, interactions|
        hour = posted_at.hour
        hourly_data[hour] += interactions
      end

      # Twitter posts by hour
      TwitterPost.where(posted_at: @start_date..@end_date)
                 .tagged_with(tag_names, any: true)
                 .pluck(:posted_at, Arel.sql('favorite_count + retweet_count'))
                 .each do |posted_at, interactions|
        hour = posted_at.hour
        hourly_data[hour] += interactions
      end

      # Ensure all 24 hours are present
      (0..23).each { |h| hourly_data[h] ||= 0 }

      hourly_data.sort.to_h
    end

    def calculate_peak_days
      tag_names = @topics.map { |t| t.tags.pluck(:name) }.flatten.uniq
      return {} if tag_names.empty?

      # Aggregate posts by day of week (0=Sunday, 6=Saturday)
      daily_data = Hash.new(0)

      # Facebook posts by day
      FacebookEntry.where(posted_at: @start_date..@end_date)
                   .tagged_with(tag_names, any: true)
                   .pluck(:posted_at, Arel.sql('reactions_total_count + comments_count + share_count'))
                   .each do |posted_at, interactions|
        day = posted_at.wday
        daily_data[day] += interactions
      end

      # Twitter posts by day
      TwitterPost.where(posted_at: @start_date..@end_date)
                 .tagged_with(tag_names, any: true)
                 .pluck(:posted_at, Arel.sql('favorite_count + retweet_count'))
                 .each do |posted_at, interactions|
        day = posted_at.wday
        daily_data[day] += interactions
      end

      # Convert to day names
      day_names = {
        0 => 'Domingo',
        1 => 'Lunes',
        2 => 'Martes',
        3 => 'Miércoles',
        4 => 'Jueves',
        5 => 'Viernes',
        6 => 'Sábado'
      }

      daily_data.transform_keys { |k| day_names[k] }
    end

    def recommend_publishing_times
      peak_hours = calculate_peak_hours
      return { morning: '9:00', afternoon: '15:00', evening: '20:00' } if peak_hours.empty?

      # Find top 3 hours
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

    # COMPETITIVE INTELLIGENCE
    def calculate_competitive_intelligence
      {
        share_of_voice: calculate_share_of_voice,
        market_position: calculate_market_position,
        growth_comparison: calculate_growth_comparison,
        competitive_topics: identify_competitive_topics
      }
    end

    def calculate_share_of_voice
      # Share of voice per topic
      total_mentions = @topics.sum do |topic|
        topic.topic_stat_dailies
             .where(topic_date: @start_date.to_date..@end_date.to_date)
             .sum(:entry_count)
      end

      return {} if total_mentions.zero?

      @topics.each_with_object({}) do |topic, hash|
        topic_mentions = topic.topic_stat_dailies
                              .where(topic_date: @start_date.to_date..@end_date.to_date)
                              .sum(:entry_count)

        hash[topic.name] = {
          mentions: topic_mentions,
          percentage: (topic_mentions.to_f / total_mentions * 100).round(1)
        }
      end
    end

    def calculate_market_position
      # Rank topics by total interactions
      ranked_topics = @topics.map do |topic|
        interactions = topic.topic_stat_dailies
                            .where(topic_date: @start_date.to_date..@end_date.to_date)
                            .sum(:total_count)
        [topic, interactions]
      end.sort_by { |_topic, interactions| -interactions }

      # Return rankings
      ranked_topics.each_with_index.map do |(topic, interactions), index|
        {
          rank: index + 1,
          topic: topic.name,
          interactions: interactions,
          share: ranked_topics.sum { |_t, i| i } > 0 ? (interactions.to_f / ranked_topics.sum { |_t, i| i } * 100).round(1) : 0
        }
      end
    end

    def calculate_growth_comparison
      @topics.each_with_object({}) do |topic, hash|
        current_period = topic.topic_stat_dailies
                              .where(topic_date: @start_date.to_date..@end_date.to_date)
                              .sum(:entry_count)

        previous_period = topic.topic_stat_dailies
                               .where(topic_date: (@start_date - @days_range.days).to_date..@start_date.to_date)
                               .sum(:entry_count)

        growth = previous_period > 0 ? ((current_period - previous_period).to_f / previous_period * 100).round(1) : 0

        hash[topic.name] = {
          current: current_period,
          previous: previous_period,
          growth: growth,
          trending: growth > 20 ? 'up' : (growth < -20 ? 'down' : 'stable')
        }
      end
    end

    def identify_competitive_topics
      # Find topics that are competing for share of voice
      sov = calculate_share_of_voice
      
      # Topics with > 15% SOV are competitive
      competitive = sov.select { |_name, data| data[:percentage] > 15 }

      competitive.map do |name, data|
        {
          topic: name,
          share: data[:percentage],
          status: data[:percentage] > 30 ? 'dominant' : (data[:percentage] > 20 ? 'strong' : 'competitive')
        }
      end
    end
  end
end


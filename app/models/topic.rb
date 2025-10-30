# frozen_string_literal: true

require 'digest'

class Topic < ApplicationRecord
  has_paper_trail on: %i[create destroy update]
  has_many :topic_stat_dailies, dependent: :destroy
  has_many :title_topic_stat_dailies, dependent: :destroy
  has_many :user_topics, dependent: :destroy
  has_many :users, through: :user_topics
  has_many :reports, dependent: :destroy
  has_many :templates, dependent: :destroy
  # has_many :topic_words, dependent: :destroy
  has_and_belongs_to_many :tags
  accepts_nested_attributes_for :tags

  before_update :remove_words_spaces

  scope :active, -> { where(status: true) }

  def tag_names
    @tag_names ||= tags.map(&:name)
  end

  def default_date_range
    { gte: DAYS_RANGE.days.ago.beginning_of_day, lte: Date.today.end_of_day }
  end

  def report_entries(start_date, end_date)
    tag_list = tag_names
    result = Entry.search(
      where: {
        published_at: { gte: start_date.beginning_of_day, lte: end_date.end_of_day },
        tags: { in: tag_list }
      },
      fields: ['id']
    )
    Entry.where(id: result.map(&:id)).enabled.order(total_count: :desc).joins(:site)
  end

  def report_title_entries(start_date, end_date)
    tag_list = tag_names
    result = Entry.search(
      where: {
        published_at: { gte: start_date.beginning_of_day, lte: end_date.end_of_day },
        title_tags: { in: tag_list }
      },
      fields: ['id']
    )
    Entry.where(id: result.map(&:id)).enabled.order(total_count: :desc).joins(:site)
  end

  def list_entries
    Rails.cache.fetch("topic_#{id}_list_entries", expires_in: 30.minutes) do
      tag_list = tag_names
      result = Entry.search(
        where: {
          published_at: default_date_range,
          tags: { in: tag_list }
        },
        order: { published_at: :desc },
        fields: ['id'], # Only return the ids to reduce payload
        load: false # Don't load the ActiveRecord objects yet (we'll do it in the next step)
      )
      entry_ids = result.map(&:id)
      Entry.where(id: entry_ids).joins(:site)
    end
  end

  def all_list_entries
    Rails.cache.fetch("topic_#{id}_all_list_entries", expires_in: 30.minutes) do
      result = Entry.search(
        where: {
          published_at: default_date_range
        },
        order: { published_at: :desc },
        fields: ['id'], # Only return the ids to reduce payload
        load: false # Don't load the ActiveRecord objects yet (we'll do it in the next step)
      )
      entry_ids = result.map(&:id)
      Entry.where(id: entry_ids).joins(:site)
    end
  end

  def title_list_entries
    tag_list = tag_names
    result = Entry.search(where: { published_at: default_date_range, title_tags: { in: tag_list } }, fields: ['id'])
    Entry.where(id: result.map(&:id)).enabled.order(published_at: :desc).joins(:site)
  end

  def chart_entries(date)
    cache_key = "topic_#{id}_chart_entries_#{date.to_date}"
    Rails.cache.fetch(cache_key, expires_in: 30.minutes) do
      tag_list = tag_names
      result = Entry.search(
        where: {
          published_at: { gte: date.beginning_of_day, lte: date.end_of_day },
          tags: { in: tag_list }
        },
        fields: [:id],
        load: false # Don't load the ActiveRecord objects yet (we'll do it in the next step)
      )
      Entry.where(id: result.map(&:id)).enabled.order(total_count: :desc).joins(:site)
      # Entry.where(id: result.map(&:id), total_count: 1..Float::INFINITY).enabled.order(total_count: :desc).joins(:site)
    end
  end

  def title_chart_entries(date)
    cache_key = "topic_#{id}_title_chart_entries_#{date.to_date}"
    Rails.cache.fetch(cache_key, expires_in: 30.minutes) do
      tag_list = tag_names
      result = Entry.search(
        where: {
          published_at: { gte: date.beginning_of_day, lte: date.end_of_day },
          title_tags: { in: tag_list }
        },
        fields: [:id],
        load: false # Don't load the ActiveRecord objects yet (we'll do it in the next step)
      )
      Entry.where(id: result.map(&:id)).enabled.order(total_count: :desc).joins(:site)
    end
  end

  def analytics_topic_entries
    tag_list = tag_names
    Entry.enabled.normal_range.tagged_with(tag_list, any: true).order(total_count: :desc).limit(20)
  end

  # ============================================
  # TEMPORAL INTELLIGENCE METHODS
  # ============================================

  # Peak Publishing Times Analysis
  # Returns hash with average engagement by hour of day
  def peak_publishing_times_by_hour
    Rails.cache.fetch("topic_#{id}_peak_times_hour", expires_in: 2.hours) do
      entries_with_engagement = list_entries.where('entries.total_count > 0')
      
      hourly_data = entries_with_engagement
        .group("HOUR(entries.published_at)")
        .select("HOUR(entries.published_at) as hour, AVG(entries.total_count) as avg_engagement, COUNT(*) as entry_count")
        .order("hour")
      
      result = {}
      hourly_data.each do |data|
        hour = data.hour.to_i
        result[hour] = {
          avg_engagement: data.avg_engagement.to_f.round(2),
          entry_count: data.entry_count
        }
      end
      result
    end
  end

  # Returns hash with average engagement by day of week (0=Sunday, 6=Saturday)
  def peak_publishing_times_by_day
    Rails.cache.fetch("topic_#{id}_peak_times_day", expires_in: 2.hours) do
      entries_with_engagement = list_entries.where('entries.total_count > 0')
      
      daily_data = entries_with_engagement
        .group("DAYOFWEEK(entries.published_at)")
        .select("DAYOFWEEK(entries.published_at) as day, AVG(entries.total_count) as avg_engagement, COUNT(*) as entry_count")
        .order("day")
      
      result = {}
      day_names = ['Domingo', 'Lunes', 'Martes', 'Miércoles', 'Jueves', 'Viernes', 'Sábado']
      
      daily_data.each do |data|
        day_num = data.day.to_i - 1 # MySQL DAYOFWEEK returns 1-7, convert to 0-6
        result[day_names[day_num]] = {
          avg_engagement: data.avg_engagement.to_f.round(2),
          entry_count: data.entry_count,
          day_number: day_num
        }
      end
      result
    end
  end

  # Combined heatmap data: hour x day of week
  def engagement_heatmap_data
    Rails.cache.fetch("topic_#{id}_engagement_heatmap", expires_in: 2.hours) do
      entries_with_engagement = list_entries.where('entries.total_count > 0')
      
      heatmap_data = entries_with_engagement
        .group("DAYOFWEEK(entries.published_at)", "HOUR(entries.published_at)")
        .select(
          "DAYOFWEEK(entries.published_at) as day",
          "HOUR(entries.published_at) as hour",
          "AVG(entries.total_count) as avg_engagement",
          "COUNT(*) as entry_count"
        )
      
      result = []
      day_names = ['Domingo', 'Lunes', 'Martes', 'Miércoles', 'Jueves', 'Viernes', 'Sábado']
      
      heatmap_data.each do |data|
        day_num = data.day.to_i - 1
        hour_num = data.hour.to_i
        
        result << {
          day: day_names[day_num],
          day_number: day_num,
          hour: hour_num,
          avg_engagement: data.avg_engagement.to_f.round(2),
          entry_count: data.entry_count
        }
      end
      result
    end
  end

  # Best time to publish (highest average engagement)
  def optimal_publishing_time
    Rails.cache.fetch("topic_#{id}_optimal_time", expires_in: 2.hours) do
      heatmap = engagement_heatmap_data
      return nil if heatmap.empty?
      
      best = heatmap.max_by { |d| d[:avg_engagement] }
      {
        day: best[:day],
        hour: best[:hour],
        avg_engagement: best[:avg_engagement],
        recommendation: "#{best[:day]} a las #{best[:hour]}:00 hrs"
      }
    end
  end

  # Content Half-Life Analysis
  # Estimates how long content stays relevant based on engagement patterns
  def content_half_life
    Rails.cache.fetch("topic_#{id}_content_half_life", expires_in: 4.hours) do
      recent_entries = list_entries.where('entries.published_at > ?', 30.days.ago)
                                   .where('entries.total_count > 0')
                                   .order('entries.published_at DESC')
                                   .limit(100)
      
      return nil if recent_entries.empty?
      
      half_lives = []
      
      recent_entries.each do |entry|
        # Estimate half-life: time when 50% of total engagement was reached
        # For simplicity, we'll use a heuristic: most engagement happens in first 24-48 hours
        age_in_hours = ((Time.current - entry.published_at) / 1.hour).to_i
        
        # If entry is less than 24 hours old, skip (not enough data)
        next if age_in_hours < 24
        
        # Heuristic: high-engagement entries stay relevant longer
        if entry.total_count > 100
          estimated_half_life = 36 # hours
        elsif entry.total_count > 50
          estimated_half_life = 24
        elsif entry.total_count > 20
          estimated_half_life = 18
        else
          estimated_half_life = 12
        end
        
        half_lives << estimated_half_life
      end
      
      return nil if half_lives.empty?
      
      {
        median_hours: median(half_lives),
        average_hours: (half_lives.sum.to_f / half_lives.size).round(1),
        sample_size: half_lives.size
      }
    end
  end

  # Trend Velocity
  # Rate of change in mentions over time (positive = growing, negative = declining)
  def trend_velocity
    Rails.cache.fetch("topic_#{id}_trend_velocity", expires_in: 1.hour) do
      recent_count = list_entries.where(published_at: 24.hours.ago..Time.current).count
      previous_count = list_entries.where(published_at: 48.hours.ago..24.hours.ago).count
      
      return 0 if previous_count.zero?
      
      velocity = ((recent_count - previous_count).to_f / previous_count * 100).round(1)
      
      {
        velocity_percent: velocity,
        recent_count: recent_count,
        previous_count: previous_count,
        trend: velocity > 10 ? 'creciendo' : (velocity < -10 ? 'decreciendo' : 'estable'),
        direction: velocity > 0 ? 'up' : (velocity < 0 ? 'down' : 'stable')
      }
    end
  end

  # Engagement Velocity (not just volume, but interaction rate)
  def engagement_velocity
    Rails.cache.fetch("topic_#{id}_engagement_velocity", expires_in: 1.hour) do
      recent_interactions = list_entries.where(published_at: 24.hours.ago..Time.current).sum(:total_count)
      previous_interactions = list_entries.where(published_at: 48.hours.ago..24.hours.ago).sum(:total_count)
      
      return 0 if previous_interactions.zero?
      
      velocity = ((recent_interactions - previous_interactions).to_f / previous_interactions * 100).round(1)
      
      {
        velocity_percent: velocity,
        recent_interactions: recent_interactions,
        previous_interactions: previous_interactions,
        trend: velocity > 15 ? 'alto' : (velocity < -15 ? 'bajo' : 'moderado'),
        direction: velocity > 0 ? 'up' : (velocity < 0 ? 'down' : 'stable')
      }
    end
  end

  # Engagement Decay Analysis
  # Shows how quickly engagement drops over time
  def engagement_decay_curve
    Rails.cache.fetch("topic_#{id}_decay_curve", expires_in: 4.hours) do
      entries_with_data = list_entries.where('entries.published_at > ?', 7.days.ago)
                                      .where('entries.total_count > 0')
      
      return [] if entries_with_data.empty?
      
      decay_points = []
      
      # Group by hours since publication
      (0..168).step(12).each do |hours_ago|
        start_time = hours_ago.hours.ago
        end_time = (hours_ago + 12).hours.ago
        
        entries_in_window = entries_with_data.where('entries.published_at': end_time..start_time)
        avg_engagement = entries_in_window.any? ? entries_in_window.average('entries.total_count').to_f.round(2) : 0
        
        decay_points << {
          hours_since_publication: hours_ago,
          avg_engagement: avg_engagement,
          entry_count: entries_in_window.count
        }
      end
      
      decay_points.reverse
    end
  end

  # Peak Activity Hours (when most content is published)
  def publishing_frequency_by_hour
    Rails.cache.fetch("topic_#{id}_publishing_frequency", expires_in: 2.hours) do
      hourly_frequency = list_entries
        .group("HOUR(entries.published_at)")
        .count
      
      Hash[hourly_frequency.map { |hour, count| [hour.to_i, count] }].sort.to_h
    end
  end

  # Temporal Summary - All temporal metrics in one call
  def temporal_intelligence_summary
    {
      optimal_time: optimal_publishing_time,
      trend_velocity: trend_velocity,
      engagement_velocity: engagement_velocity,
      content_half_life: content_half_life,
      peak_hours: peak_publishing_times_by_hour.sort_by { |_, v| -v[:avg_engagement] }.first(3),
      peak_days: peak_publishing_times_by_day.sort_by { |_, v| -v[:avg_engagement] }.first(3)
    }
  end

  # ============================================
  # FACEBOOK TEMPORAL INTELLIGENCE METHODS
  # ============================================

  def facebook_peak_publishing_times_by_hour
    Rails.cache.fetch("topic_#{id}_fb_peak_times_hour", expires_in: 2.hours) do
      tag_names = tags.pluck(:name)
      return {} if tag_names.empty?
      
      hourly_data = FacebookEntry
        .from(FacebookEntry.table_name)
        .where('facebook_entries.posted_at >= ?', DAYS_RANGE.days.ago)
        .where('reactions_total_count + comments_count + share_count > 0')
        .tagged_with(tag_names, any: true)
        .unscope(:select)
        .group("HOUR(facebook_entries.posted_at)")
        .select("HOUR(facebook_entries.posted_at) as hour, AVG(reactions_total_count + comments_count + share_count) as avg_engagement, COUNT(*) as entry_count")
      
      result = {}
      hourly_data.each do |data|
        hour = data.hour.to_i
        result[hour] = {
          avg_engagement: data.avg_engagement.to_f.round(2),
          entry_count: data.entry_count
        }
      end
      result
    end
  end

  def facebook_peak_publishing_times_by_day
    Rails.cache.fetch("topic_#{id}_fb_peak_times_day", expires_in: 2.hours) do
      tag_names = tags.pluck(:name)
      return {} if tag_names.empty?
      
      daily_data = FacebookEntry
        .from(FacebookEntry.table_name)
        .where('facebook_entries.posted_at >= ?', DAYS_RANGE.days.ago)
        .where('reactions_total_count + comments_count + share_count > 0')
        .tagged_with(tag_names, any: true)
        .unscope(:select)
        .group("DAYOFWEEK(facebook_entries.posted_at)")
        .select("DAYOFWEEK(facebook_entries.posted_at) as day, AVG(reactions_total_count + comments_count + share_count) as avg_engagement, COUNT(*) as entry_count")
      
      result = {}
      day_names = ['Domingo', 'Lunes', 'Martes', 'Miércoles', 'Jueves', 'Viernes', 'Sábado']
      
      daily_data.each do |data|
        day_num = data.day.to_i - 1
        result[day_names[day_num]] = {
          avg_engagement: data.avg_engagement.to_f.round(2),
          entry_count: data.entry_count,
          day_number: day_num
        }
      end
      result
    end
  end

  def facebook_engagement_heatmap_data
    Rails.cache.fetch("topic_#{id}_fb_engagement_heatmap", expires_in: 2.hours) do
      tag_names = tags.pluck(:name)
      return [] if tag_names.empty?
      
      heatmap_data = FacebookEntry
        .from(FacebookEntry.table_name)
        .where('facebook_entries.posted_at >= ?', DAYS_RANGE.days.ago)
        .where('reactions_total_count + comments_count + share_count > 0')
        .tagged_with(tag_names, any: true)
        .unscope(:select)
        .group("DAYOFWEEK(facebook_entries.posted_at)", "HOUR(facebook_entries.posted_at)")
        .select(
          "DAYOFWEEK(facebook_entries.posted_at) as day",
          "HOUR(facebook_entries.posted_at) as hour",
          "AVG(reactions_total_count + comments_count + share_count) as avg_engagement",
          "COUNT(*) as entry_count"
        )
      
      result = []
      day_names = ['Domingo', 'Lunes', 'Martes', 'Miércoles', 'Jueves', 'Viernes', 'Sábado']
      
      heatmap_data.each do |data|
        day_num = data.day.to_i - 1
        hour_num = data.hour.to_i
        
        result << {
          day: day_names[day_num],
          day_number: day_num,
          hour: hour_num,
          avg_engagement: data.avg_engagement.to_f.round(2),
          entry_count: data.entry_count
        }
      end
      result
    end
  end

  def facebook_optimal_publishing_time
    Rails.cache.fetch("topic_#{id}_fb_optimal_time", expires_in: 2.hours) do
      heatmap = facebook_engagement_heatmap_data
      return nil if heatmap.empty?
      
      best = heatmap.max_by { |d| d[:avg_engagement] }
      {
        day: best[:day],
        hour: best[:hour],
        avg_engagement: best[:avg_engagement],
        recommendation: "#{best[:day]} a las #{best[:hour]}:00 hrs"
      }
    end
  end

  def facebook_trend_velocity
    Rails.cache.fetch("topic_#{id}_fb_trend_velocity", expires_in: 1.hour) do
      tag_names = tags.pluck(:name)
      return { velocity_percent: 0, direction: 'stable' } if tag_names.empty?
      
      recent_count = FacebookEntry
        .where('facebook_entries.posted_at >= ?', 24.hours.ago)
        .where('facebook_entries.posted_at <= ?', Time.current)
        .tagged_with(tag_names, any: true)
        .size
        
      previous_count = FacebookEntry
        .where('facebook_entries.posted_at >= ?', 48.hours.ago)
        .where('facebook_entries.posted_at < ?', 24.hours.ago)
        .tagged_with(tag_names, any: true)
        .size
      
      return { velocity_percent: 0, direction: 'stable' } if previous_count.zero?
      
      velocity = ((recent_count - previous_count).to_f / previous_count * 100).round(1)
      
      {
        velocity_percent: velocity,
        recent_count: recent_count,
        previous_count: previous_count,
        trend: velocity > 10 ? 'creciendo' : (velocity < -10 ? 'decreciendo' : 'estable'),
        direction: velocity > 0 ? 'up' : (velocity < 0 ? 'down' : 'stable')
      }
    end
  end

  def facebook_engagement_velocity
    Rails.cache.fetch("topic_#{id}_fb_engagement_velocity", expires_in: 1.hour) do
      tag_names = tags.pluck(:name)
      return { velocity_percent: 0, direction: 'stable' } if tag_names.empty?
      
      recent_interactions = FacebookEntry
        .where('facebook_entries.posted_at >= ?', 24.hours.ago)
        .where('facebook_entries.posted_at <= ?', Time.current)
        .tagged_with(tag_names, any: true)
        .sum('reactions_total_count + comments_count + share_count')
      
      previous_interactions = FacebookEntry
        .where('facebook_entries.posted_at >= ?', 48.hours.ago)
        .where('facebook_entries.posted_at < ?', 24.hours.ago)
        .tagged_with(tag_names, any: true)
        .sum('reactions_total_count + comments_count + share_count')
      
      return { velocity_percent: 0, direction: 'stable' } if previous_interactions.zero?
      
      velocity = ((recent_interactions - previous_interactions).to_f / previous_interactions * 100).round(1)
      
      {
        velocity_percent: velocity,
        recent_interactions: recent_interactions,
        previous_interactions: previous_interactions,
        trend: velocity > 15 ? 'alto' : (velocity < -15 ? 'bajo' : 'moderado'),
        direction: velocity > 0 ? 'up' : (velocity < 0 ? 'down' : 'stable')
      }
    end
  end

  def facebook_content_half_life
    Rails.cache.fetch("topic_#{id}_fb_content_half_life", expires_in: 4.hours) do
      tag_names = tags.pluck(:name)
      return nil if tag_names.empty?
      
      recent_entries = FacebookEntry
        .where('facebook_entries.posted_at >= ?', 30.days.ago)
        .where('reactions_total_count + comments_count + share_count > 0')
        .tagged_with(tag_names, any: true)
        .order('facebook_entries.posted_at DESC')
        .limit(100)
      
      return nil if recent_entries.empty?
      
      half_lives = []
      
      recent_entries.each do |entry|
        age_in_hours = ((Time.current - entry.posted_at) / 1.hour).to_i
        next if age_in_hours < 24
        
        total_interactions = entry.reactions_total_count + entry.comments_count + entry.share_count
        
        if total_interactions > 100
          estimated_half_life = 36
        elsif total_interactions > 50
          estimated_half_life = 24
        elsif total_interactions > 20
          estimated_half_life = 18
        else
          estimated_half_life = 12
        end
        
        half_lives << estimated_half_life
      end
      
      return nil if half_lives.empty?
      
      {
        median_hours: median(half_lives),
        average_hours: (half_lives.sum.to_f / half_lives.size).round(1),
        sample_size: half_lives.size
      }
    end
  end

  def facebook_temporal_intelligence_summary
    {
      optimal_time: facebook_optimal_publishing_time,
      trend_velocity: facebook_trend_velocity,
      engagement_velocity: facebook_engagement_velocity,
      content_half_life: facebook_content_half_life,
      peak_hours: facebook_peak_publishing_times_by_hour.sort_by { |_, v| -v[:avg_engagement] }.first(3),
      peak_days: facebook_peak_publishing_times_by_day.sort_by { |_, v| -v[:avg_engagement] }.first(3)
    }
  end

  # ============================================
  # TWITTER TEMPORAL INTELLIGENCE METHODS
  # ============================================

  def twitter_peak_publishing_times_by_hour
    Rails.cache.fetch("topic_#{id}_tw_peak_times_hour", expires_in: 2.hours) do
      tag_names = tags.pluck(:name)
      return {} if tag_names.empty?
      
      hourly_data = TwitterPost
        .from(TwitterPost.table_name)
        .where('twitter_posts.posted_at >= ?', DAYS_RANGE.days.ago)
        .where('favorite_count + retweet_count + reply_count + quote_count > 0')
        .tagged_with(tag_names, any: true)
        .unscope(:select)
        .group("HOUR(twitter_posts.posted_at)")
        .select("HOUR(twitter_posts.posted_at) as hour, AVG(favorite_count + retweet_count + reply_count + quote_count) as avg_engagement, COUNT(*) as entry_count")
      
      result = {}
      hourly_data.each do |data|
        hour = data.hour.to_i
        result[hour] = {
          avg_engagement: data.avg_engagement.to_f.round(2),
          entry_count: data.entry_count
        }
      end
      result
    end
  end

  def twitter_peak_publishing_times_by_day
    Rails.cache.fetch("topic_#{id}_tw_peak_times_day", expires_in: 2.hours) do
      tag_names = tags.pluck(:name)
      return {} if tag_names.empty?
      
      daily_data = TwitterPost
        .from(TwitterPost.table_name)
        .where('twitter_posts.posted_at >= ?', DAYS_RANGE.days.ago)
        .where('favorite_count + retweet_count + reply_count + quote_count > 0')
        .tagged_with(tag_names, any: true)
        .unscope(:select)
        .group("DAYOFWEEK(twitter_posts.posted_at)")
        .select("DAYOFWEEK(twitter_posts.posted_at) as day, AVG(favorite_count + retweet_count + reply_count + quote_count) as avg_engagement, COUNT(*) as entry_count")
      
      result = {}
      day_names = ['Domingo', 'Lunes', 'Martes', 'Miércoles', 'Jueves', 'Viernes', 'Sábado']
      
      daily_data.each do |data|
        day_num = data.day.to_i - 1
        result[day_names[day_num]] = {
          avg_engagement: data.avg_engagement.to_f.round(2),
          entry_count: data.entry_count,
          day_number: day_num
        }
      end
      result
    end
  end

  def twitter_engagement_heatmap_data
    Rails.cache.fetch("topic_#{id}_tw_engagement_heatmap", expires_in: 2.hours) do
      tag_names = tags.pluck(:name)
      return [] if tag_names.empty?
      
      heatmap_data = TwitterPost
        .from(TwitterPost.table_name)
        .where('twitter_posts.posted_at >= ?', DAYS_RANGE.days.ago)
        .where('favorite_count + retweet_count + reply_count + quote_count > 0')
        .tagged_with(tag_names, any: true)
        .unscope(:select)
        .group("DAYOFWEEK(twitter_posts.posted_at)", "HOUR(twitter_posts.posted_at)")
        .select(
          "DAYOFWEEK(twitter_posts.posted_at) as day",
          "HOUR(twitter_posts.posted_at) as hour",
          "AVG(favorite_count + retweet_count + reply_count + quote_count) as avg_engagement",
          "COUNT(*) as entry_count"
        )
      
      result = []
      day_names = ['Domingo', 'Lunes', 'Martes', 'Miércoles', 'Jueves', 'Viernes', 'Sábado']
      
      heatmap_data.each do |data|
        day_num = data.day.to_i - 1
        hour_num = data.hour.to_i
        
        result << {
          day: day_names[day_num],
          day_number: day_num,
          hour: hour_num,
          avg_engagement: data.avg_engagement.to_f.round(2),
          entry_count: data.entry_count
        }
      end
      result
    end
  end

  def twitter_optimal_publishing_time
    Rails.cache.fetch("topic_#{id}_tw_optimal_time", expires_in: 2.hours) do
      heatmap = twitter_engagement_heatmap_data
      return nil if heatmap.empty?
      
      best = heatmap.max_by { |d| d[:avg_engagement] }
      {
        day: best[:day],
        hour: best[:hour],
        avg_engagement: best[:avg_engagement],
        recommendation: "#{best[:day]} a las #{best[:hour]}:00 hrs"
      }
    end
  end

  def twitter_trend_velocity
    Rails.cache.fetch("topic_#{id}_tw_trend_velocity", expires_in: 1.hour) do
      tag_names = tags.pluck(:name)
      return { velocity_percent: 0, direction: 'stable' } if tag_names.empty?
      
      recent_count = TwitterPost
        .where('twitter_posts.posted_at >= ?', 24.hours.ago)
        .where('twitter_posts.posted_at <= ?', Time.current)
        .tagged_with(tag_names, any: true)
        .size
        
      previous_count = TwitterPost
        .where('twitter_posts.posted_at >= ?', 48.hours.ago)
        .where('twitter_posts.posted_at < ?', 24.hours.ago)
        .tagged_with(tag_names, any: true)
        .size
      
      return { velocity_percent: 0, direction: 'stable' } if previous_count.zero?
      
      velocity = ((recent_count - previous_count).to_f / previous_count * 100).round(1)
      
      {
        velocity_percent: velocity,
        recent_count: recent_count,
        previous_count: previous_count,
        trend: velocity > 10 ? 'creciendo' : (velocity < -10 ? 'decreciendo' : 'estable'),
        direction: velocity > 0 ? 'up' : (velocity < 0 ? 'down' : 'stable')
      }
    end
  end

  def twitter_engagement_velocity
    Rails.cache.fetch("topic_#{id}_tw_engagement_velocity", expires_in: 1.hour) do
      tag_names = tags.pluck(:name)
      return { velocity_percent: 0, direction: 'stable' } if tag_names.empty?
      
      recent_interactions = TwitterPost
        .where('twitter_posts.posted_at >= ?', 24.hours.ago)
        .where('twitter_posts.posted_at <= ?', Time.current)
        .tagged_with(tag_names, any: true)
        .sum('favorite_count + retweet_count + reply_count + quote_count')
      
      previous_interactions = TwitterPost
        .where('twitter_posts.posted_at >= ?', 48.hours.ago)
        .where('twitter_posts.posted_at < ?', 24.hours.ago)
        .tagged_with(tag_names, any: true)
        .sum('favorite_count + retweet_count + reply_count + quote_count')
      
      return { velocity_percent: 0, direction: 'stable' } if previous_interactions.zero?
      
      velocity = ((recent_interactions - previous_interactions).to_f / previous_interactions * 100).round(1)
      
      {
        velocity_percent: velocity,
        recent_interactions: recent_interactions,
        previous_interactions: previous_interactions,
        trend: velocity > 15 ? 'alto' : (velocity < -15 ? 'bajo' : 'moderado'),
        direction: velocity > 0 ? 'up' : (velocity < 0 ? 'down' : 'stable')
      }
    end
  end

  def twitter_content_half_life
    Rails.cache.fetch("topic_#{id}_tw_content_half_life", expires_in: 4.hours) do
      tag_names = tags.pluck(:name)
      return nil if tag_names.empty?
      
      recent_posts = TwitterPost
        .where('twitter_posts.posted_at >= ?', 30.days.ago)
        .where('favorite_count + retweet_count + reply_count + quote_count > 0')
        .tagged_with(tag_names, any: true)
        .order('twitter_posts.posted_at DESC')
        .limit(100)
      
      return nil if recent_posts.empty?
      
      half_lives = []
      
      recent_posts.each do |post|
        age_in_hours = ((Time.current - post.posted_at) / 1.hour).to_i
        next if age_in_hours < 24
        
        total_interactions = post.favorite_count + post.retweet_count + post.reply_count + post.quote_count
        
        if total_interactions > 100
          estimated_half_life = 36
        elsif total_interactions > 50
          estimated_half_life = 24
        elsif total_interactions > 20
          estimated_half_life = 18
        else
          estimated_half_life = 12
        end
        
        half_lives << estimated_half_life
      end
      
      return nil if half_lives.empty?
      
      {
        median_hours: median(half_lives),
        average_hours: (half_lives.sum.to_f / half_lives.size).round(1),
        sample_size: half_lives.size
      }
    end
  end

  def twitter_temporal_intelligence_summary
    {
      optimal_time: twitter_optimal_publishing_time,
      trend_velocity: twitter_trend_velocity,
      engagement_velocity: twitter_engagement_velocity,
      content_half_life: twitter_content_half_life,
      peak_hours: twitter_peak_publishing_times_by_hour.sort_by { |_, v| -v[:avg_engagement] }.first(3),
      peak_days: twitter_peak_publishing_times_by_day.sort_by { |_, v| -v[:avg_engagement] }.first(3)
    }
  end

  private

  def remove_words_spaces
    self.positive_words = positive_words.to_s.delete(' ')
    self.negative_words = negative_words.to_s.delete(' ')
  end

  # Helper method to calculate median
  def median(array)
    return nil if array.empty?
    sorted = array.sort
    mid = sorted.length / 2
    sorted.length.odd? ? sorted[mid] : (sorted[mid - 1] + sorted[mid]) / 2.0
  end
end

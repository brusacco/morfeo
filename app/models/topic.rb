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

  # NEW: Direct entry associations for performance optimization
  has_many :entry_topics, dependent: :destroy
  has_many :entries, through: :entry_topics

  has_many :entry_title_topics, dependent: :destroy
  has_many :title_entries, through: :entry_title_topics, source: :entry

  before_update :remove_words_spaces

  # NEW: Auto-sync entries when tags are saved
  # This ensures that when an admin adds/removes tags from a topic,
  # existing entries with those tags are automatically linked
  #
  # Note: For HABTM associations, we queue the sync job after commit
  # since the association is saved after the main record
  after_commit :queue_entry_sync, on: [:create, :update]

  def queue_entry_sync
    # Queue background job to avoid blocking admin UI
    # Syncs entries from last 60 days
    # The job itself will determine if there's anything new to sync
    SyncTopicEntriesJob.perform_later(id, 60)
    Rails.logger.info "Topic #{id}: Queued entry sync job"
  rescue => e
    Rails.logger.error "Topic #{id}: Failed to queue entry sync - #{e.message}"
    # Don't raise - this shouldn't break topic saving
  end

  scope :active, -> { where(status: true) }

  def tag_names
    @tag_names ||= tags.map(&:name)
  end

  def default_date_range
    { gte: DAYS_RANGE.days.ago.beginning_of_day, lte: Date.today.end_of_day }
  end

  def report_entries(start_date, end_date)
    if ENV['USE_DIRECT_ENTRY_TOPICS'] == 'true'
      # NEW: Direct association (faster!)
      entries.enabled
             .where(published_at: start_date.beginning_of_day..end_date.end_of_day)
             .order(total_count: :desc)
             .joins(:site)
    else
      # OLD: Elasticsearch
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
  end

  def report_title_entries(start_date, end_date)
    if ENV['USE_DIRECT_ENTRY_TOPICS'] == 'true'
      # NEW: Direct association
      title_entries.enabled
                   .where(published_at: start_date.beginning_of_day..end_date.end_of_day)
                   .order(total_count: :desc)
                   .joins(:site)
    else
      # OLD: Elasticsearch
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
  end

  def list_entries
    cache_key = "topic_#{id}_list_entries#{ENV['USE_DIRECT_ENTRY_TOPICS'] == 'true' ? '_v2' : ''}"

    Rails.cache.fetch(cache_key, expires_in: 30.minutes) do
      if ENV['USE_DIRECT_ENTRY_TOPICS'] == 'true'
        # NEW: Direct association (faster!)
        # Use joins for GROUP BY compatibility
        entries.enabled
               .where(published_at: default_date_range[:gte]..default_date_range[:lte])
               .order(published_at: :desc)
               .joins(:site)
               .includes(:tags)
      else
        # OLD: Elasticsearch
        tag_list = tag_names
        result = Entry.search(
          where: {
            published_at: default_date_range,
            tags: { in: tag_list }
          },
          order: { published_at: :desc },
          fields: ['id'],
          load: false
        )
        entry_ids = result.map(&:id)
        Entry.where(id: entry_ids).includes(:site, :tags).joins(:site)
      end
    end
  end

  def all_list_entries
    cache_key = "topic_#{id}_all_list_entries#{ENV['USE_DIRECT_ENTRY_TOPICS'] == 'true' ? '_v2' : ''}"

    Rails.cache.fetch(cache_key, expires_in: 30.minutes) do
      if ENV['USE_DIRECT_ENTRY_TOPICS'] == 'true'
        # NEW: All entries (no tag filtering, just date range)
        Entry.enabled
             .where(published_at: default_date_range[:gte]..default_date_range[:lte])
             .order(published_at: :desc)
             .joins(:site)
      else
        # OLD: Elasticsearch
        result = Entry.search(
          where: {
            published_at: default_date_range
          },
          order: { published_at: :desc },
          fields: ['id'],
          load: false
        )
        entry_ids = result.map(&:id)
        Entry.where(id: entry_ids).joins(:site)
      end
    end
  end

  def title_list_entries
    cache_key = "topic_#{id}_title_list_entries#{ENV['USE_DIRECT_ENTRY_TOPICS'] == 'true' ? '_v2' : ''}"

    Rails.cache.fetch(cache_key, expires_in: 30.minutes) do
      if ENV['USE_DIRECT_ENTRY_TOPICS'] == 'true'
        # NEW: Direct association for title tags
        title_entries.enabled
                     .where(published_at: default_date_range[:gte]..default_date_range[:lte])
                     .order(published_at: :desc)
                     .joins(:site)
      else
        # OLD: Elasticsearch
        tag_list = tag_names
        result = Entry.search(where: { published_at: default_date_range, title_tags: { in: tag_list } }, fields: ['id'])
        Entry.where(id: result.map(&:id)).enabled.order(published_at: :desc).joins(:site)
      end
    end
  end

  def chart_entries(date)
    cache_key = "topic_#{id}_chart_entries_#{date.to_date}#{ENV['USE_DIRECT_ENTRY_TOPICS'] == 'true' ? '_v2' : ''}"

    Rails.cache.fetch(cache_key, expires_in: 30.minutes) do
      if ENV['USE_DIRECT_ENTRY_TOPICS'] == 'true'
        # NEW: Direct association
        entries.enabled
               .where(published_at: date.beginning_of_day..date.end_of_day)
               .order(total_count: :desc)
               .joins(:site)
      else
        # OLD: Elasticsearch
        tag_list = tag_names
        result = Entry.search(
          where: {
            published_at: { gte: date.beginning_of_day, lte: date.end_of_day },
            tags: { in: tag_list }
          },
          fields: [:id],
          load: false
        )
        Entry.where(id: result.map(&:id)).enabled.order(total_count: :desc).joins(:site)
      end
    end
  end

  def title_chart_entries(date)
    cache_key = "topic_#{id}_title_chart_entries_#{date.to_date}#{ENV['USE_DIRECT_ENTRY_TOPICS'] == 'true' ? '_v2' : ''}"

    Rails.cache.fetch(cache_key, expires_in: 30.minutes) do
      if ENV['USE_DIRECT_ENTRY_TOPICS'] == 'true'
        # NEW: Direct association for title tags
        title_entries.enabled
                     .where(published_at: date.beginning_of_day..date.end_of_day)
                     .order(total_count: :desc)
                     .joins(:site)
      else
        # OLD: Elasticsearch
        tag_list = tag_names
        result = Entry.search(
          where: {
            published_at: { gte: date.beginning_of_day, lte: date.end_of_day },
            title_tags: { in: tag_list }
          },
          fields: [:id],
          load: false
        )
        Entry.where(id: result.map(&:id)).enabled.order(total_count: :desc).joins(:site)
      end
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
    Rails.cache.fetch("topic_#{id}_peak_times_hour", expires_in: 30.minutes) do
      # Get entry IDs without joins to avoid GROUP BY issues
      entry_ids = list_entries.pluck(:id)
      entries_with_engagement = Entry.where(id: entry_ids).where('entries.total_count > 0')

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
    Rails.cache.fetch("topic_#{id}_peak_times_day", expires_in: 30.minutes) do
      # Get entry IDs without joins to avoid GROUP BY issues
      entry_ids = list_entries.pluck(:id)
      entries_with_engagement = Entry.where(id: entry_ids).where('entries.total_count > 0')

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
    Rails.cache.fetch("topic_#{id}_engagement_heatmap", expires_in: 30.minutes) do
      # Get entry IDs without joins to avoid GROUP BY issues
      entry_ids = list_entries.pluck(:id)
      entries_with_engagement = Entry.where(id: entry_ids).where('entries.total_count > 0')

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
    Rails.cache.fetch("topic_#{id}_optimal_time", expires_in: 30.minutes) do
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
    Rails.cache.fetch("topic_#{id}_content_half_life", expires_in: 30.minutes) do
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
    Rails.cache.fetch("topic_#{id}_trend_velocity", expires_in: 30.minutes) do
      recent_count = list_entries.where(published_at: 24.hours.ago..Time.current).count
      previous_count = list_entries.where(published_at: 48.hours.ago..24.hours.ago).count

      # Return hash structure even when there is no previous count
      return {
        velocity_percent: 0,
        recent_count: recent_count,
        previous_count: 0,
        trend: 'estable',
        direction: 'stable'
      } if previous_count.zero?

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
    Rails.cache.fetch("topic_#{id}_engagement_velocity", expires_in: 30.minutes) do
      recent_interactions = list_entries.where(published_at: 24.hours.ago..Time.current).sum(:total_count)
      previous_interactions = list_entries.where(published_at: 48.hours.ago..24.hours.ago).sum(:total_count)

      # Return hash structure even when there are no previous interactions
      return {
        velocity_percent: 0,
        recent_interactions: recent_interactions,
        previous_interactions: 0,
        trend: 'moderado',
        direction: 'stable'
      } if previous_interactions.zero?

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
    Rails.cache.fetch("topic_#{id}_decay_curve", expires_in: 30.minutes) do
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
    Rails.cache.fetch("topic_#{id}_publishing_frequency", expires_in: 30.minutes) do
      # Get entry IDs without joins to avoid GROUP BY issues
      entry_ids = list_entries.pluck(:id)
      hourly_frequency = Entry.where(id: entry_ids)
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
    Rails.cache.fetch("topic_#{id}_fb_peak_times_hour", expires_in: 30.minutes) do
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
    Rails.cache.fetch("topic_#{id}_fb_peak_times_day", expires_in: 30.minutes) do
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
    Rails.cache.fetch("topic_#{id}_fb_engagement_heatmap", expires_in: 30.minutes) do
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
    Rails.cache.fetch("topic_#{id}_fb_optimal_time", expires_in: 30.minutes) do
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
    Rails.cache.fetch("topic_#{id}_fb_trend_velocity", expires_in: 30.minutes) do
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
    Rails.cache.fetch("topic_#{id}_fb_engagement_velocity", expires_in: 30.minutes) do
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
    Rails.cache.fetch("topic_#{id}_fb_content_half_life", expires_in: 30.minutes) do
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
    Rails.cache.fetch("topic_#{id}_tw_peak_times_hour", expires_in: 30.minutes) do
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
    Rails.cache.fetch("topic_#{id}_tw_peak_times_day", expires_in: 30.minutes) do
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
    Rails.cache.fetch("topic_#{id}_tw_engagement_heatmap", expires_in: 30.minutes) do
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
    Rails.cache.fetch("topic_#{id}_tw_optimal_time", expires_in: 30.minutes) do
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
    Rails.cache.fetch("topic_#{id}_tw_trend_velocity", expires_in: 30.minutes) do
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
    Rails.cache.fetch("topic_#{id}_tw_engagement_velocity", expires_in: 30.minutes) do
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
    Rails.cache.fetch("topic_#{id}_tw_content_half_life", expires_in: 30.minutes) do
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

  # ============================================
  # FACEBOOK SENTIMENT ANALYSIS METHODS
  # ============================================

  def facebook_sentiment_summary(start_time: DAYS_RANGE.days.ago, end_time: Time.zone.now)
    Rails.cache.fetch("topic_#{id}_fb_sentiment_v2_#{start_time.to_date}_#{end_time.to_date}", expires_in: 30.minutes) do
      entries = FacebookEntry.for_topic(self, start_time:, end_time:)
                            .where('reactions_total_count > 0')

      return nil if entries.empty?

      # Calculate statistical validity (load to array to avoid groupdate issues)
      entries_array = entries.to_a
      total_reactions = entries_array.sum(&:reactions_total_count)
      total_posts = entries_array.size
      significant_posts = entries_array.count { |e| e.statistically_significant? }

      {
        average_sentiment: entries.average(:sentiment_score).to_f.round(2),
        sentiment_distribution: calculate_sentiment_distribution(entries),
        top_positive_posts: entries.positive_sentiment
                                  .includes(:page)
                                  .order(sentiment_score: :desc)
                                  .limit(5),
        top_negative_posts: entries.negative_sentiment
                                  .includes(:page)
                                  .order(sentiment_score: :asc)
                                  .limit(5),
        controversial_posts: entries.controversial
                                   .includes(:page)
                                   .order(controversy_index: :desc)
                                   .limit(5),
        sentiment_over_time: sentiment_over_time(entries),
        reaction_breakdown: aggregate_reaction_breakdown(entries),
        emotional_trends: emotional_intensity_analysis(entries),
        statistical_validity: {
          total_posts: total_posts,
          total_reactions: total_reactions,
          avg_reactions_per_post: (total_reactions.to_f / total_posts).round(1),
          statistically_significant_posts: significant_posts,
          significance_percentage: (significant_posts.to_f / total_posts * 100).round(1),
          overall_confidence: calculate_overall_confidence(entries)
        }
      }
    end
  end

  def facebook_sentiment_trend
    Rails.cache.fetch("topic_#{id}_fb_sentiment_trend", expires_in: 30.minutes) do
      recent = FacebookEntry.for_topic(self, start_time: 24.hours.ago)
                           .where('reactions_total_count > 0')
                           .average(:sentiment_score).to_f

      previous = FacebookEntry.for_topic(self, start_time: 48.hours.ago, end_time: 24.hours.ago)
                             .where('reactions_total_count > 0')
                             .average(:sentiment_score).to_f

      # Return default values if no data
      if recent.zero? || previous.zero?
        return {
          trend: 'stable',
          change_percent: 0.0,
          recent_score: 0.0,
          previous_score: 0.0,
          direction: 'stable'
        }
      end

      change = ((recent - previous) / previous.abs * 100).round(1)

      {
        recent_score: recent.round(2),
        previous_score: previous.round(2),
        change_percent: change,
        trend: change > 5 ? 'improving' : (change < -5 ? 'declining' : 'stable'),
        direction: change > 0 ? 'up' : (change < 0 ? 'down' : 'stable')
      }
    end
  end

  def calculate_sentiment_distribution(entries)
    # Load entries into an array to avoid conflicts with groupdate gem
    entries_array = entries.to_a
    total = entries_array.size
    return {} if total.zero?

    # Count occurrences using Ruby
    counts = entries_array.group_by(&:sentiment_label).transform_values(&:count)

    # Map enum string keys to counts
    very_positive_count = counts['very_positive'] || 0
    positive_count = counts['positive'] || 0
    neutral_count = counts['neutral'] || 0
    negative_count = counts['negative'] || 0
    very_negative_count = counts['very_negative'] || 0

    {
      very_positive: {
        count: very_positive_count,
        percentage: (very_positive_count.to_f / total * 100).round(1)
      },
      positive: {
        count: positive_count,
        percentage: (positive_count.to_f / total * 100).round(1)
      },
      neutral: {
        count: neutral_count,
        percentage: (neutral_count.to_f / total * 100).round(1)
      },
      negative: {
        count: negative_count,
        percentage: (negative_count.to_f / total * 100).round(1)
      },
      very_negative: {
        count: very_negative_count,
        percentage: (very_negative_count.to_f / total * 100).round(1)
      }
    }
  end

  def sentiment_over_time(entries, format: '%d/%m')
    # Remove existing order to avoid conflicts with GROUP BY
    entries.reorder(nil)
           .group_by_day(:posted_at, format:)
           .average(:sentiment_score)
           .transform_values { |v| v.to_f.round(2) }
  end

  def aggregate_reaction_breakdown(entries)
    {
      love: entries.sum(:reactions_love_count),
      haha: entries.sum(:reactions_haha_count),
      wow: entries.sum(:reactions_wow_count),
      like: entries.sum(:reactions_like_count),
      thankful: entries.sum(:reactions_thankful_count),
      sad: entries.sum(:reactions_sad_count),
      angry: entries.sum(:reactions_angry_count)
    }
  end

  def emotional_intensity_analysis(entries)
    # Get IDs to avoid groupdate wrapping issues
    entry_ids = entries.pluck(:id)

    {
      average_intensity: FacebookEntry.where(id: entry_ids).average(:emotional_intensity).to_f.round(2),
      high_intensity_count: FacebookEntry.where(id: entry_ids).where('emotional_intensity > ?', FacebookEntry::HIGH_EMOTION_THRESHOLD).count,
      low_intensity_count: FacebookEntry.where(id: entry_ids).where('emotional_intensity < ?', 20.0).count
    }
  end

  def calculate_overall_confidence(entries)
    # Calculate weighted average confidence based on reaction counts
    total_reactions = entries.sum(:reactions_total_count)
    return 0.0 if total_reactions.zero?

    weighted_confidence = entries.sum do |entry|
      entry.sentiment_confidence * entry.reactions_total_count
    end

    (weighted_confidence / total_reactions).round(2)
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

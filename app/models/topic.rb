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
        misspellings: false
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
        misspellings: false
      )
      Entry.where(id: result.map(&:id)).enabled.order(total_count: :desc).joins(:site)
    end
  end

  def analytics_entries(ids)
    ids_hash = Digest::MD5.hexdigest(ids.sort.join(','))
    cache_key = "topic_#{id}_analytics_entries_#{ids_hash}"
    Rails.cache.fetch(cache_key, expires_in: 30.minutes) do
      result = Entry.search(
        where: {
          published_at: default_date_range,
          id: { not: ids }
        },
        order: { published_at: :desc },
        load: false
      )
      Entry.enabled.where(id: result.map(&:id)).joins(:site)
    end
  end

  def analytics_topic_entries
    tag_list = tag_names
    Entry.enabled.normal_range.tagged_with(tag_list, any: true).order(total_count: :desc).limit(20)
  end

  private

  def remove_words_spaces
    self.positive_words = positive_words.to_s.delete(' ')
    self.negative_words = negative_words.to_s.delete(' ')
  end
end

# frozen_string_literal: true

class Topic < ApplicationRecord
  has_paper_trail on: [:create, :destroy, :update]
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

  def report_entries
    tag_list = tags.map(&:name)
    result = Entry.search(
      where: {
        published_at: { gte: 4.days.ago.beginning_of_day, lte: Date.today.end_of_day },
        tags: { in: tag_list }
      },
      fields: ['id'] # Only return the ids to reduce payload
    )
    Entry.where(id: result.map(&:id)).enabled.order(total_count: :desc).joins(:site)
  end

  def report_title_entries
    tag_list = tags.map(&:name)
    result = Entry.search(
      where: {
        published_at: { gte: 4.days.ago.beginning_of_day, lte: Date.today.end_of_day },
        title_tags: { in: tag_list }
      },
      fields: ['id']
    )
    Entry.where(id: result.map(&:id)).enabled.order(total_count: :desc).joins(:site)
  end

  def list_entries
    tag_list = tags.map(&:name)
    result = Entry.search(
      where: {
        published_at: { gte: DAYS_RANGE.days.ago.beginning_of_day, lte: Date.today.end_of_day },
        tags: { in: tag_list }
      },
      fields: ['id'] # Only return the ids to reduce payload
    )
    Entry.where(id: result.map(&:id)).enabled.order(published_at: :desc).joins(:site)
  end

  def title_list_entries
    tag_list = tags.map(&:name)
    result = Entry.search(
      where: {
        published_at: { gte: DAYS_RANGE.days.ago.beginning_of_day, lte: Date.today.end_of_day },
        title_tags: { in: tag_list }
      },
      fields: ['id']
    )
    Entry.where(id: result.map(&:id)).enabled.order(published_at: :desc).joins(:site)
  end

  def chart_entries(date)
    tag_list = tags.map(&:name)
    result = Entry.search(
      where: {
        published_at: { gte: date.beginning_of_day, lte: date.end_of_day },
        tags: { in: tag_list }
      },
      fields: [:id], misspellings: false
    )
    Entry.where(id: result.map(&:id)).enabled.order(total_count: :desc).joins(:site)
    # Entry.where(id: result.map(&:id), total_count: 1..Float::INFINITY).enabled.order(total_count: :desc).joins(:site)
  end

  def title_chart_entries(date)
    tag_list = tags.map(&:name)
    result = Entry.search(
      where: {
        published_at: { gte: date.beginning_of_day, lte: date.end_of_day },
        title_tags: { in: tag_list }
      },
      fields: [:id], misspellings: false
    )
    Entry.where(id: result.map(&:id)).enabled.order(total_count: :desc).joins(:site)
  end

  def analytics_entries(ids)
    result = Entry.search(
      where: {
        published_at: { gte: DAYS_RANGE.days.ago.beginning_of_day, lte: Date.today.end_of_day },
        id: { not: ids }
      },
      order: { published_at: :desc },
      load: false
    )
    Entry.enabled.where(id: result.map(&:id)).joins(:site)
  end

  def analytics_topic_entries
    tag_list = tags.map(&:name)
    Entry.enabled.normal_range.tagged_with(tag_list, any: true).order(total_count: :desc).limit(20)
  end

  private

  def remove_words_spaces
    self.positive_words = positive_words.gsub(' ', '')
    self.negative_words = negative_words.gsub(' ', '')
  end
end

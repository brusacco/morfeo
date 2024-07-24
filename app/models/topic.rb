# frozen_string_literal: true

class Topic < ApplicationRecord
  has_paper_trail
  has_many :topic_stat_dailies, dependent: :destroy
  has_many :user_topics, dependent: :destroy
  has_many :users, through: :user_topics
  has_many :reports, dependent: :destroy
  # has_many :topic_words, dependent: :destroy
  has_and_belongs_to_many :tags
  accepts_nested_attributes_for :tags

  before_update :remove_words_spaces

  def list_entries
    tag_list = tags.map(&:name)
    result = Entry.search(
      where: {
        published_at: { gte: DAYS_RANGE.days.ago },
        tags: { in: tag_list }
      },
      order: { published_at: :desc },
      load: false
    )
    Entry.where(id: result.map(&:id)).order(published_at: :desc).joins(:site)
  end

  def analytics_entries(ids)
    result = Entry.search(
      where: {
        published_at: { gte: DAYS_RANGE.days.ago },
        id: { not: ids }
      },
      order: { published_at: :desc },
      load: false
    )
    Entry.where(id: result.map(&:id)).joins(:site)
  end

  def analytics_topic_entries
    tag_list = tags.map(&:name)
    Entry.normal_range.tagged_with(tag_list, any: true).order(total_count: :desc).limit(20)
  end

  private

  def remove_words_spaces
    self.positive_words = positive_words.gsub(' ', '')
    self.negative_words = negative_words.gsub(' ', '')
  end
end

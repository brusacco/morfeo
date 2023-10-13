# frozen_string_literal: true

class Topic < ApplicationRecord
  has_many :user_topics
  has_many :users, through: :user_topics  
  has_many :reports, dependent: :destroy
  has_many :topic_words, dependent: :destroy
  has_and_belongs_to_many :tags
  accepts_nested_attributes_for :tags

  before_update :remove_words_spaces

  def topic_entries
    tag_list = tags.map(&:name)
    Entry.normal_range.joins(:site).tagged_with(tag_list, any: true).order(published_at: :desc)
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

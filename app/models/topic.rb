# frozen_string_literal: true

class Topic < ApplicationRecord
  has_many :reports, dependent: :destroy
  has_many :topic_words, dependent: :destroy
  has_and_belongs_to_many :tags
  accepts_nested_attributes_for :tags

  before_update :remove_words_spaces

  private

  def remove_words_spaces
    self.positive_words = positive_words.gsub(' ', '')
    self.negative_words = negative_words.gsub(' ', '')
  end
end

# frozen_string_literal: true

class Tag < ApplicationRecord
  has_and_belongs_to_many :topics
  accepts_nested_attributes_for :topics

  has_many :taggings, dependent: :destroy
  validates :name, uniqueness: true

  after_create :tag_entries
  after_update :tag_entries

  attr_accessor :interactions

  def belongs_to_any_topic?
    Topic.all.any? { |topic| topic.tag_ids.include?(id) }
  end

  private

  def tag_entries
    Tags::TagEntriesJob.perform_later(id, 1.month.ago..Time.current)
  end
end

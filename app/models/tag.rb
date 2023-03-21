# frozen_string_literal: true

class Tag < ApplicationRecord
  has_many :taggings, dependent: :destroy
  validates :name, uniqueness: true

  after_create :tag_entries
  after_update :tag_entries

  attr_accessor :interactions

  private

  def tag_entries
    Tags::TagEntriesJob.perform_later(id, 1.month.ago..Time.current)
  end
end
